(define-module (gds packages govuk)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (guix build-system ruby)
  #:use-module (guix download)
  #:use-module (guix search-paths)
  #:use-module (guix records)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages ruby)
  #:use-module (gnu packages certs)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages base)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages node)
  #:use-module (gnu packages imagemagick)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages web)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages rsync)
  #:use-module (gds build-system rails)
  #:use-module (gds packages guix)
  #:use-module (gds packages utils)
  #:use-module (gds packages utils bundler)
  #:use-module (gds packages third-party phantomjs))

(define govuk-admin-template-initialiser
  '(lambda _
     (with-output-to-file
         "config/initializers/govuk_admin_template_environment_indicators.rb"
       (lambda ()
         (display "GovukAdminTemplate.environment_style = ENV.fetch('GOVUK_ADMIN_TEMPLATE_ENVIRONMENT_STYLE', 'development')
GovukAdminTemplate.environment_label = ENV.fetch('GOVUK_ADMIN_TEMPLATE_ENVIRONMENT_LABEL', 'Dvelopment')
")))))

(define-public asset-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "01waz1v7718i7l7iv8mn7m5rl2dd2gcqqhfx18bhzdk8vyf7xx2s")))
   (package
     (name "asset-manager")
     (version "release_263")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "04sqaj5j9m80rrcv26crqkf3syx5gwfk27f01kgdp393ns6hppmm")))
     (build-system rails-build-system)
     (inputs
      `(("govuk_clamscan"
         ,
         (package
           (name "fake-govuk-clamscan")
           (version "1")
           (source #f)
           (build-system trivial-build-system)
           (arguments
            `(#:modules ((guix build utils))
              #:builder (begin
                          (use-modules (guix build utils))
                          (let
                              ((bash (string-append
                                      (assoc-ref %build-inputs "bash")
                                      "/bin/bash")))
                            (mkdir-p (string-append %output "/bin"))
                            (call-with-output-file (string-append
                                                    %output
                                                    "/bin/govuk_clamscan")
                              (lambda (port)
                                (simple-format port "#!~A\nexit 0\n" bash)))
                            (chmod (string-append %output "/bin/govuk_clamscan") #o555)
                            #t))))
           (native-inputs
            `(("bash" ,bash)))
           (synopsis "")
           (description "")
           (license #f)
           (home-page #f)))))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'create-uploads-and-fake-s3-directories
                     (lambda* (#:key outputs #:allow-other-keys)
                       (let ((out (assoc-ref outputs "out")))
                         (mkdir-p (string-append out "/uploads"))
                         (mkdir-p (string-append out "/fake-s3")))
                       #t)))))
     (synopsis "Manages uploaded assets (e.g. PDFs, images, ...)")
     (description "The Asset Manager is used to manage assets for the GOV.UK Publishing Platform")
     (license license:expat)
     (home-page "https://github.com/alphagov/asset-manager"))
   #:extra-inputs (list libffi)))

(define-public authenticating-proxy
  (package-with-bundler
   (bundle-package
    (hash (base32 "0f9ykvvrz5d56pkywzzzhhz6by5khk7yg9z54yg9l6sdcplbqc10")))
   (package
     (name "authenticating-proxy")
     (version "release_68")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0rwylyjp2dbdq16ixvhnx76mjkp67c6xiq93q57236xzmzpfyc9b")))
     (build-system rails-build-system)
     (arguments
      `(#:precompile-rails-assets? #f
        #:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-mongoid.yml
            ,(replace-mongoid.yml)))))
     (synopsis "Proxy to add authentication via Signon")
     (description "The Authenticating Proxy is a Rack based proxy,
written in Ruby that performs authentication using gds-sso, and then
proxies requests to some upstream")
     (license #f)
     (home-page "https://github.com/alphagov/authenticating-proxy"))))

(define-public bouncer
  (package-with-bundler
   (bundle-package
    (hash (base32 "1zrpg7y1h52lvah4y5ghw1szca4cmqvkba13l4ra48qpin61wkh2")))
   (package
     (name "bouncer")
     (version "release_224")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0hq9yvfxvg4gjwnb0n5fbx3ws6vnmfp91z4q0ym17mqdqz0w7yw7")))
     (build-system rails-build-system)
     (arguments
      '(#:precompile-rails-assets? #f))
     (synopsis "Rack based redirector backed by the Transition service")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/bouncer"))
   #:extra-inputs (list libffi postgresql)))

(define-public calculators
  (package-with-bundler
   (bundle-package
    (hash (base32 "17rgzq7vx6mjlqapxz8sx5wr78bij5yxp0sijdcjahh16cgbls81")))
   (package
     (name "calculators")
     (version "release_247")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0wjb3qp2bn9sbzsiswi3z0afa25a785akqgfpdwd44fyqkifnfkb")))
     (build-system rails-build-system)
     (synopsis "Calculators provides the Child benefit tax calculator")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/calculators"))
   #:extra-inputs (list libffi)))

(define-public calendars
  (package-with-bundler
   (bundle-package
    (hash (base32 "01hnqh2dxfcikhl6c1i3984qhhf9zrxi8xydsckwznv36sh8hdn8")))
   (package
     (name "calendars")
     (version "release_472")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1i38dql50qg2kchnksiqxi3kf26nj9h592fyngmw34kkb8x07yg7")))
     (build-system rails-build-system)
     (synopsis "Serves calendars on GOV.UK")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/calendars"))
   #:extra-inputs (list libffi)))

(define-public collections
  (package-with-bundler
   (bundle-package
    (hash (base32 "04i89za4bda1mssd2hlqhpczs9b0s33x7b26hbk5k3d4hc03cldg")))
   (package
     (name "collections")
     (version "release_458")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0sis5ixzp1l1qhx38rrpbd6v9rszsfmgmvk72ffwv5bl0547yz1i")))
     (build-system rails-build-system)
     (synopsis "Collections serves the new GOV.UK navigation and other pages")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/collections"))
   #:extra-inputs (list libffi)))

(define-public collections-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "1j3anlp09x0lkwfb7w29ypg6ca899srzbg08bk5l578173jcqlbp")))
   (package
     (name "collections-publisher")
     (version "release_336")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "188ih0mvzxn39csl12p87cd9wihhwa352gcs66m0i4wv61z17f6n")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "Used to create browse and topic pages")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/collections-publisher"))
   #:extra-inputs (list mariadb
                        libffi)))

(define-public contacts-admin
  (package-with-bundler
   (bundle-package
    (hash (base32 "1dzlsd2my7kd6xj194fq5xi3a2nbyib46jh8n6v1w2sf3inw22bi")))
   (package
     (name "contacts-admin")
     (version "release_404")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "02cmmaklc5hhf3xkm5vrkbmg2wxb9xibf7jhyj8cfljqym3dqr6v")))
     (build-system rails-build-system)
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
                      ,govuk-admin-template-initialiser))))
     (synopsis "Used to publish organisation contact information to GOV.UK")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/contacts-admin"))
   #:extra-inputs (list libffi
                        mariadb)))

(define-public content-performance-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "1r629qdppwfrn0x2b9yabnilbxzfwpxk5xvdqigs7v98zlc85q3v")))
   (package
     (name "content-performance-manager")
     (version "release_415")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1b9gx9clqavacy0if9m8ihvdmj83r5v5xkns6cdaa5a5p62fwl3y")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/content-performance-manager"))
   #:extra-inputs (list postgresql libffi)))

(define-public content-store
  (package-with-bundler
   (bundle-package
    (hash (base32 "03q3rkcchd9bxmlnd5idicg611fa5759xnp222hxc48cibi3zvyi")))
   (package
     (name "content-store")
     (version "release_728")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1gyd9pmw16m0imdzcyngpqklby0kzap15x45kjqz5fl4mi6s0j73")))
     (build-system rails-build-system)
     (arguments '(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/content-store"))
   #:extra-inputs (list libffi)))

(define-public content-tagger
  (package-with-bundler
   (bundle-package
    (hash (base32 "0k1r4bqkdzla8lr4g6hlggc1nz833fdxgi21wvbr1czar1yq0syv")))
   (package
     (name "content-tagger")
     (version "release_719")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0adxrgrbz4fk0pwnz2ljbqlj78njsk701byckzd4nj1i5nvracdm")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))

     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/content-tagger"))
   #:extra-inputs (list postgresql
                        libffi)))

(define-public email-alert-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "0kzy0a1krf4zh6zypbk400fdfswldq8gdh9xlk5wvii5imcm40x9")))
   (package
     (name "email-alert-api")
     (version "release_476")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0smni1qk4h3z6pwfqba10rafagi189khnjizbdbjk8vhid45ds2d")))
     (build-system rails-build-system)
     (arguments
      `(#:precompile-rails-assets? #f
        #:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/email-alert-api"))
   #:extra-inputs (list libffi postgresql)))

(define-public email-alert-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "08wjp59a5fkg6v2jwc1bvc98py2x14q233i2b8psgg5s2x9fihm3")))
   (package
     (name "email-alert-frontend")
     (version "release_121")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0gjiws57k7kphyw8wd5xayi27z775k69md9668nb2jmclm58hmdv")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/email-alert-frontend"))
   #:extra-inputs (list libffi)))

(define-public email-alert-service
  (package-with-bundler
   (bundle-package
    (hash (base32 "12zqvj75r24ibjzr84l66dcp6nz21rvxffbpwwnywz1pvr45blm0")))
   (package
     (name "email-alert-service")
     (version "release_127")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0vzq73rrk9scdy1q9pq5lzbrxfj6l6pb8b2543wa0sh744ra1faz")))
     (build-system gnu-build-system)
     (inputs
      `(("ruby" ,ruby)))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (replace 'configure (lambda args #t))
          (replace 'build (lambda args #t))
          (replace 'check (lambda args #t))
          (replace 'install
                   (lambda* (#:key inputs outputs #:allow-other-keys)
                     (let* ((out (assoc-ref outputs "out")))
                       (copy-recursively
                        "."
                        out
                        #:log (%make-void-port "w")))))
          (add-after 'patch-bin-files 'wrap-with-relative-path
                     (lambda* (#:key outputs #:allow-other-keys)
                       (let* ((out (assoc-ref outputs "out")))
                         (substitute* (find-files
                                       (string-append out "/bin"))
                           (((string-append out "/bin"))
                            "${BASH_SOURCE%/*}"))))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/email-alert-service/"))
   #:extra-inputs (list libffi)))

(define-public feedback
  (package-with-bundler
   (bundle-package
    (hash (base32 "1p0znjyll1k1aygxi3jx6zg8pks919r8kvjgixgx988m3dsj4bz6")))
   (package
     (name "feedback")
     (version "release_379")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0621k3qc54y2bn4mx5m6ngkp2y0bqldwglsszq5skqm28wy20q17")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/feedback"))
   #:extra-inputs (list libffi)))

(define-public finder-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "1v5c67k0l22h45s5zlykpgig7q4qxjdmfqlhvkz5lmhm5i1svbk4")))
   (package
     (name "finder-frontend")
     (version "release_395")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0dljqmi8zgvfic7d3kh0f1irscvwj6w6j7ic0v85nmjadqjakqh2")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/finder-frontend"))
   #:extra-inputs (list libffi)))

(define-public frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "1aw3y4jiq51zihrzc274j6l5jagm40f00kr1h6xiqkbrmwh6379p")))
   (package
     (name "frontend")
     (version "release_2834")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0cvbk33f1s9s17wrfb02zw3kaqphpk2b4ljf6p1cg76wbmi83iiy")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/frontend"))))

(define-public government-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "1y4xf21znwdnqlgs854iyfx70rwzc6q0x50g3f92xjy69dgxpn7m")))
   (package
     (name "government-frontend")
     (version "release_684")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "12csrda4n55hjg42gz1p666q0iy15g1mvvhfb97v12zrsxbcscha")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/government-frontend"))
   #:extra-inputs (list libffi)))

(define-public govuk-content-schemas
  (package
    (name "govuk-content-schemas")
    (version "release_701")
    (source
     (github-archive
      #:repository name
      #:commit-ish version
      #:hash (base32 "0rc5hyx3p6ikd2cg9mfdjshsa17kj7yzwn64xrj8c3cx4g5lcim2")))
    (build-system gnu-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (delete 'build)
         (delete 'check)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out")))
               (copy-recursively "." out)
               #t))))))
    (synopsis "govuk-content-schemas")
    (description "govuk-content-schemas")
    (license #f)
    (home-page #f)))

(define-public govuk-setenv
  (package
   (name "govuk-setenv")
   (version "1")
   (source #f)
   (build-system trivial-build-system)
   (arguments
    `(#:modules ((guix build utils))
      #:builder (begin
                  (use-modules (guix build utils))
                  (let
                      ((bash (string-append
                              (assoc-ref %build-inputs "bash")
                              "/bin/bash"))
                       (sudo (string-append
                              (assoc-ref %build-inputs "sudo")
                              "/bin/sudo")))
                    (mkdir-p (string-append %output "/bin"))
                    (call-with-output-file (string-append
                                            %output
                                            "/bin/govuk-setenv")
                      (lambda (port)
                        (simple-format port "#!~A
set -exu
APP=\"$1\"
shift
source \"/tmp/env.d/$APP\"
cd \"/var/apps/$APP\"
~A --preserve-env -u \"$APP\" \"$@\"
" bash sudo)))
                    (chmod (string-append %output "/bin/govuk-setenv") #o555)
                    #t))))
   (native-inputs
    `(("bash" ,bash)
      ("sudo" ,sudo)))
   (synopsis "govuk-setenv script for running commands in the service environment")
   (description "This script runs the specified command in an
environment similar to that which the service is running. For example,
running govuk-setenv @code{publishing-api rails console} runs the
@code{rails console} command as the user associated with the
Publishing API service, and with the environment variables for this
service setup.")
   (license #f)
   (home-page #f)))

(define-public current-govuk-guix
  (let* ((repository-root (canonicalize-path
                           (string-append (current-source-directory)
                                          "/../..")))
         (select? (delay (git-predicate repository-root))))
    (lambda ()
      (package
        (name "govuk-guix")
        (version "0")
        (source (local-file repository-root "govuk-guix-current"
                            #:recursive? #t
                            #:select? (force select?)))
        (build-system gnu-build-system)
        (inputs
         `(("coreutils" ,coreutils)
           ("bash" ,bash)
           ("guix" ,guix)
           ("guile" ,guile-2.2)))
        (arguments
         '(#:phases
           (modify-phases %standard-phases
             (replace 'configure (lambda args #t))
             (replace 'build (lambda args #t))
             (replace 'check (lambda args #t))
             (replace 'install
               (lambda* (#:key inputs outputs #:allow-other-keys)
                 (use-modules (ice-9 rdelim)
                              (ice-9 popen))
                 (let* ((out (assoc-ref outputs "out"))
                        (effective (read-line
                                    (open-pipe* OPEN_READ
                                                "guile" "-c"
                                                "(display (effective-version))")))
                        (module-dir (string-append out "/share/guile/site/"
                                                   effective))
                        (object-dir (string-append out "/lib/guile/" effective
                                                   "/site-ccache"))
                        (prefix     (string-length module-dir)))
                   (install-file "bin/govuk" (string-append out "/bin"))
                   (for-each (lambda (file)
                               (install-file
                                file
                                (string-append  out "/share/govuk-guix/bin")))
                             (find-files "bin"))
                   (copy-recursively
                    "gds"
                    (string-append module-dir "/gds")
                    #:log (%make-void-port "w"))
                   (setenv "GUILE_AUTO_COMPILE" "0")
                   (for-each (lambda (file)
                               (let* ((base (string-drop (string-drop-right file 4)
                                                         prefix))
                                      (go   (string-append object-dir base ".go")))
                                 (invoke "guild" "compile"
                                          "--warn=unused-variable"
                                          "--warn=unused-toplevel"
                                          "--warn=unbound-variable"
                                          "--warn=arity-mismatch"
                                          "--warn=duplicate-case-datum"
                                          "--warn=bad-case-datum"
                                          "--warn=format"
                                          "-L" module-dir
                                          file "-o" go)))
                             (find-files module-dir "\\.scm$"))
                   (setenv "GUIX_PACKAGE_PATH" module-dir)
                   (setenv "GUILE_LOAD_PATH" (string-append
                                              (getenv "GUILE_LOAD_PATH")
                                              ":"
                                              module-dir))
                   (setenv "GUILE_LOAD_COMPILED_PATH"
                           (string-append
                            (getenv "GUILE_LOAD_COMPILED_PATH")
                            ":"
                            object-dir))
                   #t)))
             (add-after 'install 'wrap-bin-files
               (lambda* (#:key inputs outputs #:allow-other-keys)
                 (let ((out (assoc-ref outputs "out")))
                   (wrap-program (string-append out "/bin/govuk")
                     `("PATH" prefix (,(string-append
                                        (assoc-ref inputs "coreutils")
                                        "/bin")
                                      ,(string-append
                                        (assoc-ref inputs "guile")
                                        "/bin")
                                      ,(string-append
                                        (assoc-ref inputs "bash") "/bin")))
                     `("GUILE_LOAD_COMPILED_PATH" =
                       (,(getenv "GUILE_LOAD_COMPILED_PATH")))
                     `("GUILE_LOAD_PATH" = (,(getenv "GUILE_LOAD_PATH")))
                     `("GOVUK_EXEC_PATH" suffix
                       (,(string-append out "/share/govuk-guix/bin")))
                     `("GUIX_PACKAGE_PATH" = (,(getenv "GUIX_PACKAGE_PATH")))
                     `("GUIX_UNINSTALLED" = ("true")))))))))
        (home-page #f)
        (synopsis "Package, service and system definitions for GOV.UK")
        (description "")
        (license #f)))))

(define-public hmrc-manuals-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "0agvb5hdgf91afpk9vwgr3w6s0y6xg4zsszwm52dqzndws21fcxp")))
   (package
     (name "hmrc-manuals-api")
     (version "release_237")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "182f6qfbiphhd8fk1xhjxidvzbkgy6zg2v3r94x3hzd98lhqkhlc")))
     (build-system rails-build-system)
     (arguments `(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/hmrc-manuals-api"))
   #:extra-inputs (list libffi)))

(define-public imminence
  (package-with-bundler
   (bundle-package
    (hash (base32 "15m954yry2isxp4cmgw0955hana1nny7cjn9649z4a0lnmyc02fz")))
   (package
     (name "imminence")
     (version "release_346")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0wprvmysf8vwjf0kxhksg382axgdq8v3qp584c8blw2k72b2a98b")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/imminence"))
   #:extra-inputs (list libffi)))

(define-public info-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "1nzry5yikxwwhjjxv485cykr9k955llzk8k1s4snh4489w0k1qmy")))
   (package
     (name "info-frontend")
     (version "release_117")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1wjsjp7aarbksxkhxn8clrqacys4savdcfcjb1vv18lg87lgxgsa")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/info-frontend"))
   #:extra-inputs (list libffi)))

(define-public licence-finder
  (package-with-bundler
   (bundle-package
    (hash (base32 "1cxvymhgh6fq83fijbga5igyfgrh152siiqhvnk936wwzy3rqhjr")))
   (package
     (name "licence-finder")
     (version "release_339")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1g8lp99rc2fyxkclgkkpdx9r58j7x02xx2msxp8bm4gqbrgg95dj")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/licence-finder"))))

(define-public local-links-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "01x66aqqlg8zg9a4n8jkirc1c1gs818pask45yvhpwywvck3svr5")))
   (package
     (name "local-links-manager")
     (version "release_175")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1avh0a8fij628dcvd0xsydfzpd2dcflpz72vfws3d747r7y5y9pg")))
     (build-system rails-build-system)
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
            ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/local-links-manager"))
   #:extra-inputs (list postgresql
                        libffi)))

(define-public manuals-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "0rx39zd4f44v43jl2svibka8nf9rh6fl96yda6r6c888n21gis29")))
   (package
     (name "manuals-frontend")
     (version "release_273")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0xv4a8xk0zbb8bkzg9qfmxjr1j2j1jprxcy7i9zy6j88ab3shz2w")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/manuals-frontend"))
   #:extra-inputs (list libffi)))

(define-public manuals-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "1w9d0sahvc6988iyamvjm381gdh9gmhcs2qswsfhx5ycmqc9mb0m")))
   (package
     (name "manuals-publisher")
     (version "release_1062")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0g88sjx7j4h2x8kp46x00ld173dhalrx02frsbcpxdi9f5a65c0k")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after
              'install 'alter-secrets.yml
            (lambda* (#:key outputs #:allow-other-keys)
              (substitute* (string-append
                            (assoc-ref outputs "out")
                            "/config/secrets.yml")
                (("SECRET_TOKEN")
                "SECRET_KEY_BASE")))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/manuals-publisher"))
   #:extra-inputs (list libffi)))

(define-public maslow
  (package-with-bundler
   (bundle-package
    (hash (base32 "1ww1cnispijbg8z4lcr2mmjky3i7p9984c8fzf974cq1m6rpjr2p")))
   (package
     (name "maslow")
     (version "release_250")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1hcrrmdkkyjpb5848mlyypq9xjqwd4fk6d7p52099iy57zkf3lkq")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-mongoid.yml
                     ,(replace-mongoid.yml))
          (add-after 'replace-mongoid.yml 'replace-gds-sso-initializer
                     ,(replace-gds-sso-initializer)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/maslow"))
   #:extra-inputs (list libffi)))

(define-public policy-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "1makpvc8ha4n9hascx5c82m0rmaacxfakivzmjsxxnlzj4gl6h1i")))
   (package
     (name "policy-publisher")
     (version "release_238")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "18fpvswan641cphns84l07dh2bm58px5ypx6ahbd875m5kdxk7wa")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/policy-publisher"))
   #:extra-inputs (list libffi
                        postgresql)))

(define-public publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "0adxjjs88p0cndd6j6sv3sans6ga8vw6c8jyzi8dvf6sn8qacrns")))
   (package
     (name "publisher")
     (version "release_1919")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1sddk1qqd022xl1dl77p5dwq7jwg3jbljmxs0nsdl8hw8bi6qfjy")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-mongoid.yml
                     ,(replace-mongoid.yml))
          (add-after 'replace-mongoid.yml 'replace-gds-sso-initializer
                     ,(replace-gds-sso-initializer)))))
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/publisher"))
   #:extra-inputs (list libffi)))

(define-public publishing-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "05r523piildk9vd3z30w1b8595l5kra5wmk9bibw7749cj2d0whw")))
   (package
     (name "publishing-api")
     (version "release_1136")
     (source
      (github-archive
       #:repository "publishing-api"
       #:commit-ish version
       #:hash (base32 "1111syrf09dkj4yhyf3mffyb9r15fvvx1imb6vs7vw3zss6kwxzl")))
     (build-system rails-build-system)
     (arguments '(#:precompile-rails-assets? #f))
     (synopsis "Service for storing and providing workflow for GOV.UK content")
     (description
      "The Publishing API is a service that provides a HTTP API for
managing content for GOV.UK.  Publishing applications can use the
Publishing API to manage their content, and the Publishing API will
populate the appropriate Content Stores (live or draft) with that
content, as well as broadcasting changes to a message queue.")
     (license license:expat)
     (home-page "https://github.com/alphagov/publishing-api"))
   #:extra-inputs (list
                   libffi
                   ;; Required by the pg gem
                   postgresql)))

(define-public publishing-e2e-tests
  (package-with-bundler
   (bundle-package
    (hash
     (base32 "1ygjwxvsvyns0ygn74bqacjipdyysf6xhdw3b434nqzaa93jchqs")))
   (package
     (name "publishing-e2e-tests")
     (version "0")
     (source
      (github-archive
       #:repository "publishing-e2e-tests"
       #:commit-ish "c57f87fbf5615705e95fe13031b62ad501f9d5fe"
       #:hash (base32 "016rc11df3spfhpfnyzrrppwwihxlny0xvc2d98bsdc43b78kjb2")))
     (build-system gnu-build-system)
     (inputs
      `(("ruby" ,ruby)
        ("phantomjs" ,phantomjs)))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (replace 'configure (lambda args #t))
          (replace 'build (lambda args #t))
          (replace 'check (lambda args #t))
          (replace 'install
                   (lambda* (#:key inputs outputs #:allow-other-keys)
                     (let* ((out (assoc-ref outputs "out")))
                       (copy-recursively
                        "."
                        out
                        #:log (%make-void-port "w"))
                       (mkdir-p (string-append out "/tmp/results"))))))))
     (synopsis "Suite of end-to-end tests for GOV.UK")
     (description "")
     (license license:expat)
     (home-page "https://github.com/alphagov/publishing-e2e-tests"))
   #:extra-inputs (list
                   libffi
                   ;; For nokogiri
                   pkg-config
                   libxml2
                   libxslt)))

(define-public release
  (package-with-bundler
   (bundle-package
    (hash (base32 "01r22d5wgs35iya8a6r5bfrcwmxmjhg46qkghy5nj3nym3sfc1p5")))
   (package
     (name "release")
     (version "release_270")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0qgjk3lcszvhzawr311lrpik4r9pwmpkqb0zn151pgrdz0dd28ry")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/release"))
   #:extra-inputs (list mariadb
                        libffi)))

(define-public router
  (package
    (name "router")
    (version "release_184")
    (source
     (github-archive
      #:repository name
      #:commit-ish version
      #:hash (base32 "1bi82ha49vapyrp90glz21x3zzf43wazsxndfaspfmxdb2ihkzdz")))
    (build-system gnu-build-system)
    (native-inputs
     `(("go" ,go)))
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (delete 'install)
         (delete 'check)
         (replace 'build
                  (lambda* (#:key inputs outputs #:allow-other-keys)
                    (let* ((out (assoc-ref outputs "out"))
                           (cwd (getcwd)))
                      (copy-recursively cwd "../router-copy")
                      (mkdir-p "__build/src/github.com/alphagov")
                      (mkdir-p "__build/bin")
                      (setenv "GOPATH" (string-append cwd "/__build"))
                      (setenv "BINARY" (string-append cwd "/router"))
                      (rename-file "../router-copy"
                                   "__build/src/github.com/alphagov/router")
                      (and
                       (with-directory-excursion
                           "__build/src/github.com/alphagov/router"
                         (and
                          (zero? (system*
                                  "make" "build"
                                          (string-append "RELEASE_VERSION="
                                                         ,version)))
                          (mkdir-p (string-append out "/bin"))))
                       (begin
                         (copy-file "router"
                                    (string-append out "/bin/router"))
                         #t))))))))
    (synopsis "")
    (description "")
    (license "")
    (home-page "https://github.com/alphagov/router")))

(define-public router-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "00c1a7hndh9jilf3fmf66a5qxxs0w2y5a8f01cmy1rqkifbwaqh9")))
   (package
     (name "router-api")
     (version "release_143")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0dkkl6cf5296g470bcfpla4bv5p5aygqy79p0bsxcwlbvdci13rz")))
     (build-system rails-build-system)
     (arguments '(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/router-api"))
   #:extra-inputs (list libffi)))

(define-public rummager
  (package-with-bundler
   (bundle-package
    (hash (base32 "0238pb5c69843ldlk1lgwzx2lnwcdbcgf3icgfndsif2dvidj3ws")))
   (package
     (name "rummager")
     (version "release_1713")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1rzpgyyx81x9l2rhbj690gw550nhc4c9ikxr092xbzzg80b482ms")))
     (build-system rails-build-system)
     (arguments '(#:precompile-rails-assets? #f))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/rummager"))
   #:extra-inputs (list libffi)))

(define-public search-admin
  (package-with-bundler
   (bundle-package
    (hash (base32 "1ghfp0yjhgxsyb1121zvka1jvxf89papqjhmcnlb8smy2wjsj2bs")))
   (package
     (name "search-admin")
     (version "release_147")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "11i0fyc1bz94jznrw8hfyal3gjh5lbjhq4fcqp29r7y4hphrjikr")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/search-admin"))
   #:extra-inputs (list libffi
                        mariadb)))

(define-public service-manual-frontend
  (package-with-bundler
   (bundle-package
    (hash (base32 "0ycq9hyim3vlxmdnq1hy76fm67j3s5djx9bzhax5f007kxw3rkd1")))
   (package
     (name "service-manual-frontend")
     (version "release_115")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0bz2k7ipiwzw8j54h9h9j3kbv0ixyqsrldlxih6rqw9jgi40jq84")))
     (build-system rails-build-system)
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/service-manual-frontend"))
   #:extra-inputs (list libffi)))

(define-public service-manual-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "10gmfjq5nnm9ibk56mzjni03031hvwkim62kg1y0djmypdawzacv")))
   (package
     (name "service-manual-publisher")
     (version "release_329")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1ihlxqhq0vfh8ypw0b73m5h7riyynpds5wra4pl4a2k2p1gzwsiv")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser))))
     (inputs
      `(;; Loading the database structure uses psql
        ("postgresql" ,postgresql)))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/service-manual-publisher"))
   #:extra-inputs (list libffi
                        postgresql)))

(define-public short-url-manager
  (package-with-bundler
   (bundle-package
    (hash (base32 "0f5nqakyik2ag8l97cdampgzqrkl0aq0d02qpi27kynbb6xyfzhy")))
   (package
     (name "short-url-manager")
     (version "release_169")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "11lvfij1bcls79f11y03npxxms1v12xh9d9m4frl2zlv685wwkab")))
     (build-system rails-build-system)
     ;; Asset precompilation fails due to trying to connect to MongoDB
     (arguments
      `(#:precompile-rails-assets? #f
        #:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/short-url-manager"))
   #:extra-inputs (list libffi)))

(define-public signon
  (package-with-bundler
   (bundle-package
    (hash (base32 "15w78rmwcs0q9hk44k3dik9kz4qkmxp2x6a1l3vfx35yrn74asmd"))
    (without '("development" "test")))
   (package
     (name "signon")
     (version "release_989")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1sqkjhdypf0am869cg3pshidvj66fg4x0y6knpcr41qwsmr51f6i")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'precompile-rails-assets 'set-dummy-devise-environment
            (lambda _
              (setenv "DEVISE_PEPPER" "dummy-govuk-guix-value")
              (setenv "DEVISE_SECRET_KEY" "dummy-govuk-guix-value")))
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          ;; Ideally this would be configurable, but as it's not, lets
          ;; just disable it
          (add-before 'install 'disable-google-analytics
            (lambda _
              (substitute* "config/initializers/govuk_admin_template.rb"
                (("false") "true"))))
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/signon"))
   #:extra-inputs (list libffi
                        mariadb
                        postgresql
                        openssl)))

(define-public smart-answers
  (package-with-bundler
   (bundle-package
    (hash (base32 "1jabaynwghvzadb9gkplzibvmb7hc98ysjsv17fz7pb8fmz53b4w")))
   (package
     (name "smart-answers")
     (version "release_3872")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0vby9par3pcij05bjayabss9v5yglcwgibkzp8mik3pjqv43vlc4")))
     (build-system rails-build-system)
     ;; Asset precompilation fails due to the preload_working_days
     ;; initialiser
     (arguments
      '(#:precompile-rails-assets? #f
        #:phases
        (modify-phases %standard-phases
          (add-before 'install 'delete-test
            (lambda _
              ;; This directory is large, ~50,000 files, so remove it
              ;; from the package to save space
              (delete-file-recursively "test"))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/smart-answers"))
   #:extra-inputs (list libffi)))

(define-public specialist-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "0ndirc8wz49c97sh8wcn8h2940065adphvw7brcvl4vhi5wp38vr"))
    (without '("development" "test")))
   (package
     (name "specialist-publisher")
     (version "release_920")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1lnd1sv0iy3zjlmdbrfy3qn9pbzyym88w2f0z92gs6hm2frma90w")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after
           'install 'alter-secrets.yml
           (lambda* (#:key outputs #:allow-other-keys)
             (substitute* (string-append
                           (assoc-ref outputs "out")
                           "/config/secrets.yml")
               (("SECRET_TOKEN")
                "SECRET_KEY_BASE")))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/specialist-publisher"))
   #:extra-inputs (list libffi)))

(define-public smokey
  (package-with-bundler
   (bundle-package
    (hash (base32 "19rzqm6731swpgyz0477vbk7kxysmjgaa8nh26jmwvps7701jl12")))
   (package
     (name "smokey")
     (version "0")
     (source
      (github-archive
       #:repository name
       #:commit-ish "61cd5a70ca48eb9a6e5ca2522d608db75dbb6582"
       #:hash (base32 "1n1ah83nps1bkqgpq8rd1v6c988w9mvkacrphwg7zz1d6k8fqska")))
     (build-system gnu-build-system)
     (inputs
      `(("ruby" ,ruby)
        ("phantomjs" ,phantomjs)))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (replace 'configure (lambda args #t))
          (replace 'build (lambda args #t))
          (replace 'check (lambda args #t))
          (replace 'install
                   (lambda* (#:key inputs outputs #:allow-other-keys)
                     (let* ((out (assoc-ref outputs "out")))
                       (copy-recursively
                        "."
                        out
                        #:log (%make-void-port "w")))))
          (add-after 'patch-bin-files 'wrap-with-relative-path
                     (lambda* (#:key outputs #:allow-other-keys)
                       (let* ((out (assoc-ref outputs "out")))
                         (substitute* (find-files
                                       (string-append out "/bin"))
                           (((string-append out "/bin"))
                            "${BASH_SOURCE%/*}"))))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/smokey/"))
   #:extra-inputs (list
                   ;; For nokogiri
                   pkg-config
                   libxml2
                   libxslt)))

(define-public static
  (package-with-bundler
   (bundle-package
    (hash (base32 "1vqqrgw5b4iw5pwiifz9zrirlpdlivm9zs7wa17gg2nfd0w6jzns")))
   (package
     (name "static")
     (version "release_2802")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1h0bl9vhl1sj9r06222m9b0bfh1p74qacbrrzr2ddvj0cx8dpf6i")))
     (build-system rails-build-system)
     (arguments
      '(#:phases
        (modify-phases %standard-phases
          (add-after 'install 'remove-redundant-page-caching
            (lambda* (#:key outputs #:allow-other-keys)
              ;; TODO: This caching causes problems, as the public
              ;; directory is not writable, and it also looks
              ;; redundant, as I can't see how the files are being
              ;; served from this directory.
              (substitute*
                  (string-append
                   (assoc-ref outputs "out")
                   "/app/controllers/root_controller.rb")
                (("  caches_page.*$")
                 "")))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/static"))
   #:extra-inputs (list
                   libffi)))

(define-public support
  (package-with-bundler
   (bundle-package
    (hash (base32 "1klfpnbb95zbl88m66rp7825a02ni3wr6b5fhg1rs6cy69949bgm")))
   (package
     (name "support")
     (version "release_646")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "0wa6am72hh8rk8hs47ckjy4jjjsnmvy6g33xbmdfykf24cbdxsp2")))
     (build-system rails-build-system)
     (arguments
      `(#:precompile-rails-assets? #f ;; Asset precompilation fails,
                                      ;; as it tries to connect to
                                      ;; redis
        #:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after
           'install 'replace-redis.yml
           ,(replace-redis.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/support"))
   #:extra-inputs (list libffi)))

(define-public support-api
  (package-with-bundler
   (bundle-package
    (hash (base32 "19ri6s7bjx780gbh5vhqxv0dqldy7diamzncap6mk7kha5p19k0g")))
   (package
     (name "support-api")
     (version "release_164")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "13dnz805781367mhk425knc07dlb532hq8qksrqccxrc6xjj81g7")))
     (build-system rails-build-system)
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)
        ;; Loading the database structure uses psql
        ("postgresql" ,postgresql)))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/support-api"))
   #:extra-inputs (list postgresql libffi)))

(define-public transition
  (package-with-bundler
   (bundle-package
    (hash (base32 "10hs6gq7mfc72ln4327q7rmv3x6a7khrq5rj01nyssx7yywf751r")))
   (package
     (name "transition")
     (version "release_842")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1j6pddcfbw6zvs31rb4iljs5xz22djfi0423jf9p4cf5vjm4pr7i")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser))))
     (inputs
      `(;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/transition"))
   #:extra-inputs (list libffi
                        postgresql)))

(define-public travel-advice-publisher
  (package-with-bundler
   (bundle-package
    (hash (base32 "1za0c4ra10025vk3wibn6ncw9skmyzfq6pykivihznpq9p6sm5p3")))
   (package
     (name "travel-advice-publisher")
     (version "release_345")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "1ma5xpj3kgwr96scxr5mw3jhkm459c28wwbklddp2z1l01497v8v")))
     (build-system rails-build-system)
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-mongoid.yml
            ,(replace-mongoid.yml)))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/travel-advice-publisher"))
   #:extra-inputs (list libffi)))

(define-public whitehall
  (package-with-bundler
   (bundle-package
    (hash (base32 "0310qqfng8qpr5vg2s9y01kwcsjq4213g5fgy9bmhfj1kkhk77if")))
   (package
     (name "whitehall")
     (version "release_13311")
     (source
      (github-archive
       #:repository name
       #:commit-ish version
       #:hash (base32 "173j99krirbrxs41wcvfm6sxcqlbxylgadq65qgr4kd0818ki1lz")))
     (build-system rails-build-system)
     (inputs
      `(("node" ,node)
        ;; TODO Adding curl here is unusual as ideally the gem
        ;; requiring it would link against the exact location of the
        ;; library at compile time.
        ("curl" ,curl)
        ;; hostname is needed by the redis-lock gem
        ("inetutils" ,inetutils)))
     (arguments
      `(#:phases
        (modify-phases %standard-phases
          (add-before 'install 'add-govuk-admin-template-initialiser
            ,govuk-admin-template-initialiser)
          (add-after 'install 'replace-database.yml
                     ,(use-blank-database.yml))
          (add-after 'install 'set-bulk-upload-zip-file-tmp
                     (lambda* (#:key outputs #:allow-other-keys)
                       (substitute* (string-append
                                     (assoc-ref outputs "out")
                                     "/config/initializers/bulk_upload_zip_file.rb")
                         (("Rails\\.root\\.join\\('bulk-upload-zip-file-tmp'\\)")
                          "\"/tmp/whitehall/bulk-upload-zip-file\"")))))))
     (synopsis "")
     (description "")
     (license #f)
     (home-page "https://github.com/alphagov/whitehall"))
   #:extra-inputs (list mariadb
                        libffi
                        curl
                        imagemagick)))
