;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2016 Roel Janssen <roel@gnu.org>
;;;
;;; This file is not officially part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gds packages third-party mongodb)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python))

(define-public mongodb
  (package
    (name "mongodb")
    (version "3.4.4")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/mongodb/mongo/archive/r"
                                  version ".tar.gz"))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256
               (base32 "1ccd6azplqpi9pp3l6fsi8240kkgagq5j6c2dksppjn7slk1kdy8"))
              (patches (list (search-patch "mongodb-add-version-file.patch")))))
    (build-system gnu-build-system)
    (native-inputs
     `(("scons" ,scons)
       ("python" ,python-2)
       ("perl" ,perl)
       ;; MongoDB requires GCC 5.3.0 or later.
       ("gcc" ,gcc-5)))
    (arguments
     `(#:tests? #f ; There is no 'check' target.
       #:phases
       (modify-phases %standard-phases
         (delete 'configure) ; There is no configure phase
         (add-after 'unpack 'scons-propagate-environment
           (lambda _
             ;; Modify the SConstruct file to arrange for
             ;; environment variables to be propagated.
             (substitute* "SConstruct"
               (("^env = Environment\\(")
                "env = Environment(ENV=os.environ, "))))
         (replace 'build
           (lambda _
             (zero? (system* "scons"
                             (format #f "--jobs=~a" (parallel-job-count))
                             "mongod" "mongo" "mongos"))))
         (replace 'install
           (lambda _
             (let ((bin  (string-append (assoc-ref %outputs "out") "/bin")))
               (install-file "mongod" bin)
               (install-file "mongos" bin)
               (install-file "mongo" bin)))))))
    (home-page "https://www.mongodb.org/")
    (synopsis "High performance and high availability document database")
    (description "Mongo is a high-performance, high availability,
schema-free document-oriented database.  A key goal of MongoDB is to bridge
the gap between key/value stores (which are fast and highly scalable) and
traditional RDBMS systems (which are deep in functionality).")
    (license (list license:agpl3 license:asl2.0))))

(define-public mongo-tools
  (package
    (name "mongo-tools")
    (version "3.4.0")
    (source
     (origin (method url-fetch)
             (uri (string-append "https://github.com/mongodb/" name
                                 "/archive/r" version ".tar.gz"))
             (file-name (string-append name "-" version ".tar.gz"))
             (sha256
              (base32
               "1xbcpnz2hz1wj5q5i3yqpcqh3g8ychyr2896m9z2v4l5sz5xcd23"))))
    (build-system gnu-build-system)
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (delete 'check)
         (delete 'install)
         (replace 'build
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((bash (string-append
                          (assoc-ref inputs "bash")
                          "/bin/bash"))
                   (out (assoc-ref outputs "out")))
               (and
                (zero? (system* bash "set_gopath.sh"))
                (begin
                  (setenv "GOPATH" (string-join
                                    (list
                                     (string-append (getcwd) "/.gopath")
                                     (string-append (getcwd) "/vendor"))
                                    ":"))
                  (mkdir-p (string-append out "/bin"))
                  (setenv "GOBIN" (string-append out "/bin"))
                  #t)
                (and
                 (map
                  (lambda (tool)
                    (zero?
                     (system*
                      "go"
                      "install"
                      "-v"
                      "-tags=\"ssl sasl\""
                      "-ldflags"
                      "-extldflags=-Wl,-z,now,-z,relro"
                      (string-append tool "/main/" tool ".go"))))
                  '("bsondump" "mongodump" "mongoexport" "mongofiles" "mongoimport"
                    "mongooplog" "mongorestore" "mongostat" "mongotop"))))))))))
    (native-inputs
     `(("go" ,go)
       ("bash" ,bash)))
    (home-page "https://github.com/mongodb/mongo-tools")
    (synopsis "")
    (description "")
    (license "expat")))
