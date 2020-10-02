(ns main
  (:require [taoensso.carmine :as car]))

(def server-conn { :pool {} :spec { :db 3 }})
(defmacro with-connection [& body] `(car/wcar server-conn ~@body))

(defn run []
  (with-connection
    (car/set "foo" { :hey 123 })
    (println (car/get "foo")))

(defn main [& args] (run))
