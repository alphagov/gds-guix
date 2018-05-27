(define-module (gds data transformations mysql)
  #:use-module (guix gexp)
  #:use-module (gnu packages base)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages pv)
  #:use-module (gnu services)
  #:use-module (gnu services databases)
  #:export (with-mysql))

(define* (with-mysql
          mysql-service
          gexp-to-run
          #:key (base-directory #~(string-append
                                   (getcwd)
                                   "/mysql")))

  (let ((mysql ((@@ (gnu services databases) mysql-configuration-mysql)
                (service-value mysql-service))))
    (with-imported-modules '((guix build utils))
      #~(begin
          (add-to-load-path #$(file-append shepherd
                                           "/share/guile/site/"
                                           (effective-version)))

          (use-modules (shepherd service)
                       (guix build utils))

          (define base-directory #$base-directory)

          (setenv "PATH"
                  (list->search-path-as-string
                   (cons* #$(file-append mysql "/bin")
                          #$(file-append pv "/bin")
                          #$(file-append gzip "/bin")
                          ;; TODO: mysql_install_db uses mkdir and sed
                          #$(file-append coreutils "/bin")
                          #$(file-append sed "/bin")
                          (search-path-as-string->list (getenv "PATH")))
                   ":"))

          (define configuration-file
            (string-append (getcwd) "/my.cnf"))

          (define socket-file
            (string-append (getcwd) "/mysqld.sock"))

          (setenv "MYSQL_UNIX_PORT" socket-file)

          (call-with-output-file configuration-file
            (lambda (port)
              (display "[mysqld]\n" port)
              (display (string-append "datadir=" base-directory "\n")
                       port)
              (display (string-append "socket=" socket-file "\n")
                       port)
              (display "max_allowed_packet=16M\n" port)
              (display "\n" port)))

          (mkdir-p base-directory)
          (invoke #$(file-append mysql "/bin/mysql_install_db")
                  (string-append "--datadir=" base-directory))

          (simple-format #t "\nSuccessfully boostrapped MySQL\n\n")
          (force-output)

          ((make-forkexec-constructor
            (list #$(file-append mysql "/bin/mysqld")
                  (string-append "--defaults-file=" configuration-file)
                  "--pid-file=/tmp/mysql.pid")
            #:pid-file "/tmp/mysql.pid"))

          (let ((result
                 (#$gexp-to-run)))
            result)))))
