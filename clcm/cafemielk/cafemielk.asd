(defsystem "cafemielk"
  :description
  "Cafemielk: Another FEM Implementation for Electromagnetic Field Computation"
  :version "0.0.1"
  :author "Nagamine, Hideaki <nagamine.hideaki.88x@kyoto-u.jp>"
  :license "BSD"
  :depends-on ()
  :components ((:file "util")
               (:file "linalg" :depends-on ("util"))))