(define-module (gds packages third-party ruby)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix download)
  #:use-module (guix packages)
  #:use-module (gnu packages)
  #:use-module (gnu packages ruby)
  #:use-module (gnu packages rails)
  #:use-module (guix build-system ruby))

(define-public ruby-bootstrap-sass
  (package
    (name "ruby-bootstrap-sass")
    (version "3.3.7")
    (source
     (origin
       (method url-fetch)
       (uri (rubygems-uri "bootstrap-sass" version))
       (sha256
        (base32
         "1bc9bf6caddqn1rv15b5x56yczmbjzaxzl9lk5zbwrg1bfph4bx9"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f))
    (propagated-inputs
     `(("ruby-autoprefixer-rails" ,ruby-autoprefixer-rails)
       ("ruby-sass" ,ruby-sass)))
    (synopsis "Sass-powered version of Bootstrap 3")
    (description
     "bootstrap-sass is a Sass-powered version of Bootstrap 3, ready to drop right into your Sass powered applications.")
    (home-page "https://github.com/twbs/bootstrap-sass")
    (license license:expat)))

(define-public ruby-jquery-rails
  (package
    (name "ruby-jquery-rails")
    (version "4.3.1")
    (source
     (origin
       (method url-fetch)
       (uri (rubygems-uri "jquery-rails" version))
       (sha256
        (base32
         "02ii77vwxc49f2lrkbdzww2168bp5nihwzakc9mqyrsbw394w7ki"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f))
    (native-inputs
     `(("bundler" ,bundler)))
    (propagated-inputs
     `(("ruby-rails-dom-testing" ,ruby-rails-dom-testing)
       ("ruby-railties" ,ruby-railties)
       ("ruby-thor" ,ruby-thor)))
    (synopsis "jQuery and the jQuery-ujs driver for your Rails")
    (description
     "This gem provides jQuery and the jQuery-ujs driver for your Rails 4+
application.")
    (home-page "http://rubygems.org/gems/jquery-rails")
    (license license:expat)))
