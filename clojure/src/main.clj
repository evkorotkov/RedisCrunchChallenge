(ns main
  (:require [taoensso.carmine :as car]
            [clojure.core.async :as async :refer [go chan]]))

(def host (or (System/getenv "REDIS_HOST") "127.0.0.1"))
(def server-conn { :pool {} :spec { :host host }})
(defmacro with-connection [& body] `(car/wcar server-conn ~@body))

(defn run []
  (let [result (with-connection
                  (car/set "foo" "bar")
                  (car/get "foo"))]
    (println result)))

(defn -main [& args] (run))
