(define-module (gds services govuk)
  #:use-module (srfi srfi-1)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu system shadow)
  #:use-module ((gnu packages admin)
                #:select (shadow))
  #:use-module (guix records)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (ice-9 match)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (gnu packages base)
  #:use-module (gnu packages databases)
  #:use-module (gds packages govuk)
  #:use-module (gds services sidekiq)
  #:use-module (gds services govuk signon)
  #:use-module (gds services rails)
  #:use-module (gds packages mongodb)
  #:export (ports

            govuk-content-schemas-service-type
            govuk-content-schemas-service

            rails-app-config
            rails-app-config?

            update-rails-app-config-environment
            update-rails-app-config-with-random-secret-key-base
            update-rails-app-config-with-random-secret-token

            rails-app-service
            rails-app-service-type

            signon-config
            signon-config?
            signon-config-rails-app-config
            signon-config-applications

            router-config
            router-config?
            router-config-public-port
            router-config-api-port

            router-api-config
            router-api-config?
            router-api-nodes

            publishing-api-service
            content-store-service
            draft-content-store-service
            specialist-publisher-service
            publishing-e2e-tests-service
            router-service
            draft-router-service
            router-api-service
            draft-router-api-service
            maslow-service
            need-api-service

            signon-service-type
            signon-service

            static-service))

(define ports
  (make-parameter
   `((postgresql . 5432)
     (mongodb . 27017)
     (publishing-api . 3039)
     (content-store . 3000)
     (draft-content-store . 3001)
     (specialist-publisher . 3064))))

(define-record-type* <router-api-config>
  router-api-config make-router-api-config
  router-api-config?
  (router-nodes router-api-config-router-nodes
                (default '())))

;;;
;;; GOV.UK Content Schemas
;;;

(define govuk-content-schemas-service-type
  (shepherd-service-type
   'govuk-content-schemas
   (lambda (package)
     (shepherd-service
      (provision (list 'govuk-content-schemas))
      (documentation "Ensure /var/lib/govuk-content-schemas exists")
      (start
       #~(lambda _
           (use-modules (guix build utils))

           (if (not (file-exists? "/var/lib/govuk-content-schemas"))
               (begin
                 (mkdir-p "/var/lib")
                 (symlink #$package
                          "/var/lib/govuk-content-schemas")))
           #t))
   (stop #~(lambda _
             #f))
   (respawn? #f)))))

(define govuk-content-schemas-service
  (service govuk-content-schemas-service-type govuk-content-schemas))




(define (make-rails-app-using-signon-service-type name . rest)
  (let ((base-service-type
         (apply make-rails-app-service-type name rest)))
    (service-type
     (inherit base-service-type)
     (extensions
      (cons
       (service-extension signon-service-type
                          (lambda (parameters)
                            (filter
                             signon-application?
                             parameters)))
       (service-type-extensions base-service-type))))))

;;;
;;; Signon
;;;

(define-record-type* <signon-config>
  signon-config make-signon-config
  signon-config?
  (applications signon-config-applications
                (default '())))

(define signon-service-type
  (service-type
   (inherit
    (make-rails-app-service-type 'signon))
   (compose list)
   (extend (lambda (parameters applications)
             (match parameters
               ((plek-config rails-app-config package config rest ...)
                (cons*
                 plek-config
                 rails-app-config
                 package
                 (signon-config
                  (inherit config)
                  (applications (append
                                 (signon-config-applications config)
                                 applications)))
                 rest)))))))

(define default-signon-database-connection-configs
  (list
   (mysql-connection-config
    (host "localhost")
    (user "halberd")
    (port "-")
    (database "signon-production")
    (password ""))
   (redis-connection-config)))

(define signon-service
  (service
   signon-service-type
   (cons* (plek-config) (rails-app-config) signonotron2
          (signon-config) (sidekiq-config) default-signon-database-connection-configs)))

;;
;; Publishing E2E Tests
;;

(define (make-publishing-e2e-tests-start-script environment-variables package)
  (let*
      ((environment-variables
        (append
         environment-variables
         `(("SECRET_KEY_BASE" . "t0a")
           ("CAPYBARA_SAVE_PATH" . "/tmp/guix/")
           ("GOVUK_CONTENT_SCHEMAS_PATH" . "/var/lib/govuk-content-schemas")))))
    (program-file
     (string-append "start-publishing-e2e-tests")
     (with-imported-modules '((guix build utils)
                              (ice-9 popen))
       #~(let ((user (getpwnam "nobody"))
               (bundle (string-append #$package "/bin/bundle")))
           (use-modules (guix build utils)
                        (ice-9 popen))

           (mkdir-p "/var/lib/publishing-e2e-tests")
           (chown "/var/lib/publishing-e2e-tests"
                  (passwd:uid user) (passwd:gid user))

           ;; Start the service
           (setgid (passwd:gid user))
           (setuid (passwd:uid user))
           (for-each
            (lambda (env-var)
              (setenv (car env-var) (cdr env-var)))
            '#$environment-variables)
           (chdir #$package)
           (and
            (zero? (system* bundle "exec" "rspec"))))))))

(define publishing-e2e-tests-service-type
  (service-type
   (name 'publishing-e2e-tests-service)
   (extensions
    (list (service-extension
           shepherd-root-service-type
           (match-lambda
            ((plek-config package)
             (let* ((start-script
                     (make-publishing-e2e-tests-start-script
                      (plek-config->environment-variables plek-config)
                      package)))
               (list
                (shepherd-service
                 (provision (list 'publishing-e2e-tests))
                 (documentation "publishing-e2e-tests")
                 (requirement '(specialist-publisher))
                 (respawn? #f)
                 (start #~(make-forkexec-constructor #$start-script))
                 (stop #~(make-kill-destructor))))))))))))

(define publishing-e2e-tests-service
  (service
   publishing-e2e-tests-service-type
   (list (plek-config) publishing-e2e-tests)))

;;;
;;; Publishing API Service
;;;

(define default-publishing-api-database-connection-configs
  (list
   (postgresql-connection-config
    (user "publishing-api")
    (port "5432")
    (database "publishing_api_production"))))

(define default-publishing-api-signon-application
  (signon-application
   (name "publishing-api")
   (description "")
   (redirect-uri "")
   (home-uri "")
   (uid "uid")))

(define publishing-api-service-type
  (make-rails-app-service-type
   'publishing-api
   #:requirements '(content-store draft-content-store)))

(define publishing-api-service
  (service
   publishing-api-service-type
   (cons* (plek-config) (rails-app-config) publishing-api
          default-publishing-api-signon-application
          (sidekiq-config)
          default-publishing-api-database-connection-configs)))

;;;
;;; Content store
;;;

(define default-content-store-database-connection-configs
  (list
   (mongodb-connection-config
    (user "content-store")
    (password (random-base16-string 30))
    (database "content-store"))))

(define content-store-service-type
  (make-rails-app-using-signon-service-type
   'content-store
   #:requirements '(mongodb)))

(define content-store-service
  (service
   content-store-service-type
   (cons* (plek-config) (rails-app-config) content-store
          default-content-store-database-connection-configs)))

(define default-draft-content-store-database-connection-configs
  (list
   (mongodb-connection-config
    (user "draft-content-store")
    (password (random-base16-string 30))
    (database "draft-content-store"))))

(define draft-content-store-service-type
  (make-rails-app-service-type 'draft-content-store))

(define draft-content-store-service
  (service
   draft-content-store-service-type
   (cons* (plek-config) (rails-app-config) content-store
          default-draft-content-store-database-connection-configs)))

;;;
;;; Specialist Publisher
;;;

(define default-specialist-publisher-database-connection-configs
  (list
   (mongodb-connection-config
    (user "specialist-publisher")
    (password (random-base16-string 30))
    (database "specialist_publisher"))))

(define default-specialist-publisher-service-startup-config
  (service-startup-config
   (pre-startup-scripts
    (list
     (run-command "rake" "db:seed")
     (run-command "rake" "publishing_api:publish_finders")
     (run-command "rake" "permissions:grant[David Heath]")))))

(define specialist-publisher-service-type
  (make-rails-app-using-signon-service-type
   'specialist-publisher
   #:requirements '(publishing-api)))

(define specialist-publisher-service
  (service
   specialist-publisher-service-type
   (cons* (plek-config) (rails-app-config) specialist-publisher
          default-specialist-publisher-service-startup-config
          default-specialist-publisher-database-connection-configs)))

;;;
;;; Specialist Frontend
;;;

(define specialist-frontend-service-type
  (make-rails-app-using-signon-service-type
   'specialist-frontend
   #:requirements '(content-store)))

(define specialist-frontend-service
  (service
   specialist-frontend-service-type
   (list (plek-config) (rails-app-config) specialist-frontend)))

;;;
;;; Router
;;;

(define-record-type* <router-config>
  router-config make-router-config
  router-config?
  (public-port router-config-public-port
               (default 8080))
  (api-port router-config-api-port
            (default 8081))
  (debug? router-config-debug
          (default #f)))

(define router-config->environment-variables
  (match-lambda
    (($ <router-config> public-port api-port debug?)
     (append
      (list
       (cons "ROUTER_PUBADDR" (simple-format #f ":~A" public-port))
       (cons "ROUTER_APIADDR" (simple-format #f ":~A" api-port)))
      (if debug?
          (list (cons "DEBUG" "true"))
          '())))))

(define (make-router-start-script environment-variables package . rest)
  (let*
      ((database-connection-configs
        (filter database-connection-config? rest))
       (environment-variables
        (map
         (match-lambda
           ((name . value)
            (cond
             ((equal? name "MONGO_DB")
              (cons "ROUTER_MONGO_DB" value))
             ((equal? name "MONGODB_URI")
              (cons "ROUTER_MONGO_URL" value))
             (else
              (cons name value)))))
         (append
          environment-variables
          (concatenate
           (map database-connection-config->environment-variables
                database-connection-configs))))))
    (program-file
     (string-append "start-router")
     (with-imported-modules '((guix build utils)
                              (ice-9 popen))
       #~(let ((user (getpwnam "nobody")))
           (use-modules (guix build utils)
                        (ice-9 popen))

           ;; Start the service
           (setgid (passwd:gid user))
           (setuid (passwd:uid user))

           (display "\n")
           (for-each
            (lambda (env-var)
              (simple-format
               #t
               "export ~A=~A\n"
               (car env-var)
               (cdr env-var))
              (setenv (car env-var) (cdr env-var)))
            '#$environment-variables)
           (display "\n")

           (chdir #$package)
           (and
            (zero? (system* (string-append #$package "/bin/router")))))))))

(define (make-router-shepherd-service name)
  (match-lambda
    ((router-config package rest ...)
     (let* ((start-script
             (apply
              make-router-start-script
              (router-config->environment-variables router-config)
              package
              rest)))
       (list
        (shepherd-service
         (provision (list name))
         (documentation (symbol->string name))
         (requirement '())
         (respawn? #f)
         (start #~(make-forkexec-constructor #$start-script))
         (stop #~(make-kill-destructor))))))))

(define (make-router-service-type name)
  (service-type
   (name name)
   (extensions
    (list (service-extension shepherd-root-service-type
                             (make-router-shepherd-service name))))))

(define default-router-database-connection-configs
  (list
   (mongodb-connection-config
    (user "router")
    (password (random-base16-string 30))
    (database "router"))))

(define router-service-type
  (make-router-service-type 'router))

(define router-service
  (service
   router-service-type
   (cons* (router-config) router
          default-router-database-connection-configs)))

(define default-draft-router-database-connection-configs
  (list
   (mongodb-connection-config
    (user "draft-router")
    (password (random-base16-string 30))
    (database "draft-router"))))

(define draft-router-service-type
  (make-router-service-type 'draft-router))

(define draft-router-service
  (service
   draft-router-service-type
   (cons* (router-config) router
          default-draft-router-database-connection-configs)))

;;;
;;; Router API
;;;

(define-record-type* <router-api-config>
  router-api-config make-router-api-config
  router-api-config?
  (router-nodes router-api-config-router-nodes
                (default '())))

(define router-api-service-type
  (make-rails-app-using-signon-service-type
   'router-api
   #:requirements '(router)))

(define router-api-service
  (service
   router-api-service-type
   (cons* (plek-config) (rails-app-config) router-api
          (router-api-config)
          default-router-database-connection-configs)))

(define draft-router-api-service-type
  (make-rails-app-using-signon-service-type
   'draft-router-api
   #:requirements '(draft-router)))

(define draft-router-api-service
  (service
   draft-router-api-service-type
   (cons* (plek-config) (rails-app-config) router-api
          (router-api-config)
          default-draft-router-database-connection-configs)))

;;;
;;; Maslow
;;;

(define default-maslow-database-connection-configs
  (list
   (mongodb-connection-config
    (user "maslow")
    (password (random-base16-string 30))
    (database "maslow"))))

(define maslow-service-type
  (make-rails-app-using-signon-service-type
   'maslow
   #:requirements '(publishing-api)))

(define maslow-service
  (service
   maslow-service-type
   (cons* (plek-config) (rails-app-config) maslow
          default-maslow-database-connection-configs)))

;;;
;;; Need API
;;;

(define default-need-api-database-connection-configs
  (list
   (mongodb-connection-config
    (user "need-api")
    (password (random-base16-string 30))
    (database "govuk_needs_development"))))

(define need-api-service-type
  (make-rails-app-using-signon-service-type
   'need-api
   #:requirements '(publishing-api)))

(define need-api-service
  (service
   need-api-service-type
   (cons* (plek-config) (rails-app-config) need-api
          default-need-api-database-connection-configs)))

;;;
;;; Static service
;;;

(define static-service-type
  (make-rails-app-service-type 'static))

(define static-service
  (service
   static-service-type
   (list (service-startup-config) (plek-config) (rails-app-config)
         static)))

(define draft-static-service-type
  (make-rails-app-service-type 'draft-static))

(define draft-static-service
  (service
   draft-static-service-type
   (list (service-startup-config
          (environment-variables
           '(("DRAFT_ENVIRONMENT" . "true"))))
         (plek-config) (rails-app-config) static)))
