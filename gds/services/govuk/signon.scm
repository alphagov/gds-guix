(define-module (gds services govuk signon)
  #:use-module (guix records)
  #:export (<signon-application>
            signon-application
            signon-application?
            signon-application-name
            signon-application-description
            signon-application-redirect-uri
            signon-application-home-uri
            signon-application-uid
            signon-application-secret

            <gds-sso-config>
            gds-sso-config
            gds-sso-config?
            gds-sso-config-strategy

            gds-sso-config->environment-variables))

(define-record-type* <signon-application>
  signon-application make-signon-application
  signon-application?
  (name signon-application-name)
  (description signon-application-name)
  (redirect-uri signon-application-name)
  (home-uri signon-application-name)
  (uid signon-application-name
       (default #f))
  (secret signon-application-name
          (default #f)))

(define-record-type* <gds-sso-config>
  gds-sso-config make-gds-sso-config
  gds-sso-config?
  (strategy gds-sso-config-strategy
            (default "real")))

(define (gds-sso-config->environment-variables gds-sso-config)
  (list
   (cons "GDS_SSO_STRATEGY" (gds-sso-config-strategy gds-sso-config))))
