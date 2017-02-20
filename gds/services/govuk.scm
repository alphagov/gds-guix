(define-module (gds services govuk)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
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
  #:use-module (gds services)
  #:use-module (gds services utils)
  #:use-module (gds services utils databases)
  #:use-module (gds services utils databases postgresql)
  #:use-module (gds services utils databases mysql)
  #:use-module (gds services utils databases mongodb)
  #:use-module (gds services govuk plek)
  #:use-module (gds services sidekiq)
  #:use-module (gds services govuk signon)
  #:use-module (gds services rails)
  #:use-module (gds packages mongodb)
  #:export (govuk-content-schemas-service-type
            govuk-content-schemas-service

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

            publishing-api-service-type
            publishing-api-service
            content-store-service-type
            content-store-service
            draft-content-store-service-type
            draft-content-store-service

            specialist-publisher-service-type
            specialist-publisher-service

            specialist-frontend-service-type
            specialist-frontend-service
            publishing-e2e-tests-service-type
            publishing-e2e-tests-service
            router-service
            router-service-type
            draft-router-service
            draft-router-service-type
            router-api-service
            router-api-service-type
            draft-router-api-service
            draft-router-api-service-type
            maslow-service
            maslow-service-type
            need-api-service
            need-api-service-type

            signon-service-type
            signon-service
            static-service-type
            static-service
            info-frontend-service-type
            info-frontend-service

            publishing-application-services
            api-services
            supporting-application-services
            frontend-services
            draft-frontend-services))

;;;
;;; Utilities
;;;

(define (make-rails-app-using-plek-service-type name)
  (extend-service-type-with-plek
   (make-rails-app-service-type name)))

(define (make-rails-app-using-plek-and-signon-service-type name)
  (let ((base-service-type
         (make-rails-app-using-plek-service-type name)))
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
;;; GOV.UK Content Schemas
;;;

(define govuk-content-schemas-service-type
  (shepherd-service-type
   'govuk-content-schemas
   (lambda (package)
     (shepherd-service
      (provision (list 'govuk-content-schemas))
      (documentation "Ensure /var/apps/govuk-content-schemas exists")
      (start
       #~(lambda _
           (use-modules (guix build utils))

           (if (not (file-exists? "/var/apps/govuk-content-schemas"))
               (begin
                 (mkdir-p "/var/apps")
                 (symlink #$package
                          "/var/apps/govuk-content-schemas")))
           #t))
   (stop #~(lambda _
             #f))
   (respawn? #f)))))

(define govuk-content-schemas-service
  (service govuk-content-schemas-service-type govuk-content-schemas))

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
    (make-rails-app-using-plek-service-type 'signon))
   (compose list)
   (extend (lambda (parameters applications)
             (map
              (lambda (parameter)
                (if (signon-config? parameter)
                    (signon-config
                     (inherit parameter)
                     (applications (append
                                    (signon-config-applications parameter)
                                    applications)))
                    parameter))
              parameters)))))

(define default-signon-database-connection-configs
  (list
   (mysql-connection-config
    (host "localhost")
    (user "halberd")
    (port "-")
    (database "signon_production")
    (password ""))
   (redis-connection-config)))

(define signon-service
  (service
   signon-service-type
   (cons* (shepherd-service
           (inherit default-shepherd-service)
           (provision '(signon))
           (requirement '(mysql)))
          (service-startup-config)
          (plek-config) (rails-app-config) (@ (gds packages govuk) signon)
          (signon-config)
          (sidekiq-config
           (file "config/sidekiq.yml"))
          default-signon-database-connection-configs)))

;;
;; Publishing E2E Tests
;;

(define (make-publishing-e2e-tests-start-script environment-variables package)
  (let*
      ((environment-variables
        (append
         environment-variables
         `(("SECRET_KEY_BASE" . "t0a")
           ("CAPYBARA_SAVE_PATH" . "/var/apps/publishing-e2e-tests/")
           ("GOVUK_CONTENT_SCHEMAS_PATH" . "/var/apps/govuk-content-schemas")))))
    (program-file
     (string-append "start-publishing-e2e-tests")
     (with-imported-modules '((guix build utils)
                              (gnu services herd)
                              (srfi srfi-26)
                              (ice-9 popen)
                              (ice-9 rw)
                              (ice-9 rdelim))
       #~(let ((bundle (string-append #$package "/bin/bundle"))
               (test-results.html
                "/var/apps/publishing-e2e-tests/test-results.html"))
           (use-modules (guix build utils)
                        (gnu services herd)
                        (srfi srfi-26)
                        (ice-9 popen)
                        (ice-9 rw)
                        (ice-9 rdelim))

           (mkdir-p "/var/apps/publishing-e2e-tests")

           (for-each
            (lambda (env-var)
              (setenv (car env-var) (cdr env-var)))
            '#$environment-variables)
           (chdir #$package)
           (let
               ((result
                 (zero? (system*
                         bundle
                         "exec"
                         "rspec"
                         "--format" "documentation"
                         "--format" "html"
                         "--out" test-results.html))))

             ;; Links to pages and screenshots are absolute, so turn
             ;; them in to relative links so that they work outside of
             ;; the container
             (let ((substring "file:///var/apps/publishing-e2e-tests/"))
               (with-atomic-file-replacement test-results.html
                 (lambda (in out)
                   (write-string/partial
                     (let filter ((str (read-string in)))
                       (let ((index (string-contains str substring)))
                         (if index
                             (filter
                              (string-replace
                               str
                               ""
                               index
                               (+ index (string-length substring))))
                             str)))
                     out))))

             ;; Change file permissions to be writable by all
             (for-each (lambda (f) (chmod f #o666))
                       (find-files "/var/apps/publishing-e2e-tests"))

             (if result
                 (call-with-output-file
                     "/var/apps/publishing-e2e-tests/all-tests-succeeded"
                   (lambda (port)
                     (simple-format port ""))))

             (stop-service 'root)
             result))))))

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
    (database "publishing_api_production"))
   (redis-connection-config)))

(define default-publishing-api-signon-application
  (signon-application
   (name "publishing-api")
   (description "")
   (redirect-uri "")
   (home-uri "")
   (uid "uid")))

(define publishing-api-service-type
  (make-rails-app-using-plek-service-type 'publishing-api))

(define publishing-api-service
  (service
   publishing-api-service-type
   (cons* (shepherd-service
           (inherit default-shepherd-service)
           (provision '(publishing-api))
           (requirement '(content-store draft-content-store)))
          (service-startup-config
           (environment-variables
            '(("GOVUK_CONTENT_SCHEMAS_PATH" . "/var/apps/govuk-content-schemas"))))
          (plek-config) (rails-app-config) publishing-api
          default-publishing-api-signon-application
          (sidekiq-config
           (file "config/sidekiq.yml"))
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
  (make-rails-app-using-plek-and-signon-service-type 'content-store))

(define content-store-service
  (service
   content-store-service-type
   (cons* (shepherd-service
           (inherit default-shepherd-service)
           (provision '(content-store))
           (requirement '(router-api mongodb)))
          (service-startup-config)
          (plek-config) (rails-app-config) content-store
          default-content-store-database-connection-configs)))

(define default-draft-content-store-database-connection-configs
  (list
   (mongodb-connection-config
    (user "draft-content-store")
    (password (random-base16-string 30))
    (database "draft-content-store"))))

(define draft-content-store-service-type
  (make-rails-app-using-plek-service-type 'draft-content-store))

(define draft-content-store-service
  (service
   draft-content-store-service-type
   (cons* (shepherd-service
           (inherit default-shepherd-service)
           (provision '(draft-content-store))
           (requirement '(draft-router-api mongodb)))
          (service-startup-config)
          (plek-config) (rails-app-config) content-store
          default-draft-content-store-database-connection-configs)))

;;;
;;; Specialist Publisher
;;;

(define default-specialist-publisher-database-connection-configs
  (list
   (mongodb-connection-config
    (user "specialist-publisher")
    (password (random-base16-string 30))
    (database "specialist_publisher"))
   (redis-connection-config)))

(define specialist-publisher-service-type
  (make-rails-app-using-plek-and-signon-service-type 'specialist-publisher))

(define specialist-publisher-service
  (service
   specialist-publisher-service-type
   (cons* (shepherd-service
           (inherit default-shepherd-service)
           (provision '(specialist-publisher))
           (requirement '(publishing-api)))
          (plek-config) (rails-app-config) specialist-publisher
          (service-startup-config)
          default-specialist-publisher-database-connection-configs)))

;;;
;;; Specialist Frontend
;;;

(define specialist-frontend-service-type
  (make-rails-app-using-plek-and-signon-service-type 'specialist-frontend))

(define specialist-frontend-service
  (service
   specialist-frontend-service-type
   (list (shepherd-service
          (inherit default-shepherd-service)
          (provision '(specialist-frontend))
          (requirement '(content-store static)))
         (service-startup-config
          (environment-variables
           '(("GOVUK_APP_NAME" . "specialist-frontend"))))
         (plek-config) (rails-app-config) specialist-frontend)))

(define draft-specialist-frontend-service-type
  (make-rails-app-using-plek-and-signon-service-type 'draft-specialist-frontend))

(define draft-specialist-frontend-service
  (service
   draft-specialist-frontend-service-type
   (list (shepherd-service
          (inherit default-shepherd-service)
          (provision '(draft-specialist-frontend))
          (requirement '(draft-content-store draft-static)))
         (service-startup-config
          (environment-variables
           '(("GOVUK_APP_NAME" . "draft-specialist-frontend"))))
         (plek-config) (rails-app-config) specialist-frontend)))

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

(define (make-router-shepherd-service name)
  (match-lambda
    ((router-config package rest ...)
     (let ((environment-variables
            (map
             (match-lambda
              ((key . value)
               (string-append key "=" value)))
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
               (router-config->environment-variables router-config)
               (concatenate
                (map database-connection-config->environment-variables
                     (filter database-connection-config? rest)))))))
           (user (getpwnam "nobody"))
           (string-service-name
            (symbol->string name)))
       (list
        (shepherd-service
         (provision (list name))
         (documentation string-service-name)
         (requirement '(mongodb))
         (respawn? #f)
         (start #~(make-forkexec-constructor
                   (string-append #$package "/bin/router")
                   #:user (passwd:uid #$user)
                   #:environment-variables '#$environment-variables
                   #:log-file (string-append "/var/log/" #$string-service-name)))
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
  (make-rails-app-using-plek-and-signon-service-type 'router-api))

(define router-api-service
  (service
   router-api-service-type
   (cons* (shepherd-service
           (inherit default-shepherd-service)
           (provision '(router-api))
           (requirement '(router)))
          (service-startup-config)
          (plek-config) (rails-app-config) router-api
          (router-api-config)
          default-router-database-connection-configs)))

(define draft-router-api-service-type
  (make-rails-app-using-plek-and-signon-service-type 'draft-router-api))

(define draft-router-api-service
  (service
   draft-router-api-service-type
   (cons* (shepherd-service
           (inherit default-shepherd-service)
           (provision '(draft-router-api))
           (requirement '(draft-router)))
          (service-startup-config)
          (plek-config) (rails-app-config) router-api
          (router-api-config)
          default-draft-router-database-connection-configs)))

;;;
;;; Content Tagger
;;;

(define default-content-tagger-database-connection-configs
  (list
   (postgresql-connection-config
    (user "content-tagger")
    (port "5432")
    (database "content_tagger"))))

(define content-tagger-service-type
  (make-rails-app-using-plek-and-signon-service-type 'content-tagger))

(define content-tagger-service
  (service
   content-tagger-service-type
   (cons* (shepherd-service
           (inherit default-shepherd-service)
           (provision '(content-tagger))
           (requirement '(publishing-api signon)))
          (service-startup-config)
          (plek-config) (rails-app-config) content-tagger
          default-content-tagger-database-connection-configs)))

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
  (make-rails-app-using-plek-and-signon-service-type 'maslow))

(define maslow-service
  (service
   maslow-service-type
   (cons* (shepherd-service
           (inherit default-shepherd-service)
           (provision '(maslow))
           (requirement '(publishing-api need-api signon)))
          (service-startup-config)
          (plek-config) (rails-app-config) maslow
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
  (make-rails-app-using-plek-and-signon-service-type 'need-api))

(define need-api-service
  (service
   need-api-service-type
   (cons* (shepherd-service
           (inherit default-shepherd-service)
           (provision '(need-api))
           (requirement '(publishing-api)))
          (service-startup-config)
          (plek-config) (rails-app-config) need-api
          default-need-api-database-connection-configs)))

;;;
;;; Info Frontend
;;;

(define info-frontend-service-type
  (make-rails-app-using-plek-service-type 'info-frontend))

(define info-frontend-service
  (service
   info-frontend-service-type
   (list (shepherd-service
          (inherit default-shepherd-service)
          (provision '(info-frontend))
          (requirement '(content-store publishing-api)))
         (service-startup-config) (plek-config) (rails-app-config)
         info-frontend)))

;;;
;;; Static service
;;;

(define static-service-type
  (make-rails-app-using-plek-service-type 'static))

(define static-service
  (service
   static-service-type
   (list (shepherd-service
          (inherit default-shepherd-service)
          (provision '(static))
          (requirement '(publishing-api)))
         (service-startup-config) (plek-config) (rails-app-config)
         static)))

(define draft-static-service-type
  (make-rails-app-using-plek-service-type 'draft-static))

(define draft-static-service
  (service
   draft-static-service-type
   (list (shepherd-service
          (inherit default-shepherd-service)
          (provision '(draft-static))
          (requirement '(publishing-api)))
         (service-startup-config
          (environment-variables
           '(("DRAFT_ENVIRONMENT" . "true"))))
         (plek-config) (rails-app-config) static)))

;;;
;;; Service Lists
;;;

(define publishing-application-services
  (list
   ;; collections-publisher-service
   ;; contacts-admin-service
   content-tagger-service
   ;; local-links-manager-service
   ;; manuals-publisher-service
   maslow-service
   ;; policy-publisher-service
   ;; publisher-service
   ;; service-manual-publisher-service
   ;; short-url-manager-service
   specialist-publisher-service
   ;; travel-advice-publisher-service
   ;; whitehall-service
   ))

(define api-services
  (list
   ;; business-support-api-service
   content-store-service
   draft-content-store-service
   ;; email-alert-api-service
   ;; email-alert-service-service
   ;; content-api-service
   need-api-service
   ;; imminence-service
   publishing-api-service
   ;; rummager-service
   ;; asset-manager-service
   router-api-service
   draft-router-api-service
   ;; support-api-service
   ;; hmrc-manuals-api-service
   ;; mapit-service
   ;; metadata-api-service
   ))

(define supporting-application-services
  (list
   ;; bouncer-service
   ;; authenticating-proxy-service
   ;; search-admin-service
   signon-service
   ;; support-service
   ;; transition-service
   ;; release-service
   router-service
   draft-router-service))

(define frontend-services
  (list
   ;; business-support-finder-service
   ;; calculators-service
   ;; calendars-service
   ;; collections-service
   ;; contacts-frontend-service
   ;; design-principles-service
   ;; email-alert-frontend-service
   ;; feedback-service
   ;; finder-frontend-service
   ;; frontend-service
   ;; government-frontend-service
   info-frontend-service
   ;; licence-finder-service
   ;; manuals-frontend-service
   ;; multipage-frontend-service
   ;; smart-answers-service
   ;; service-manual-frontend-service
   specialist-frontend-service
   static-service))

(define draft-frontend-services
  (list
   ;; draft-collections-service
   ;; draft-contacts-service
   ;; draft-email-alert-service
   ;; draft-government-frontend-service
   ;; draft-manuals-frontend-service
   ;; draft-multipage-frontend-service
   ;; draft-service-manual-frontend-service
   draft-static-service
   draft-specialist-frontend-service))
