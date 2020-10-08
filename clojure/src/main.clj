(ns main
  (:require [taoensso.carmine :as car]
            [clojure.core.async :as async :refer [go chan <!! >!!]]
            [clojure.data.csv :as csv]
            [clojure.data.json :as json]
            [clojure.java.io :as io]
            [digest]))

(def host (or (System/getenv "REDIS_HOST") "127.0.0.1"))
(def server-conn { :pool {} :spec { :host host }})
(defmacro with-connection [& body] `(car/wcar server-conn ~@body))

(def discounts [0 5 10 15 20 25 30])

(defn brpop []
  (with-connection
    (car/brpop "events_queue" 5)))

(defn now [] (str (System/currentTimeMillis)))
(defn round [val] (/ (Math/round (* val 100)) 100))

(defn calc-total [evt]
  (let [price (evt :price)
        discount (/ (discounts (evt :wday)) 100)]
    (round (* price (- 1 discount)))))

(defn handle-event [evt]
  (let [parsed (json/read-str evt :key-fn keyword)
        total (calc-total parsed)]
    (assoc parsed :total total)))

(defn signature [evt]
  (-> evt json/write-str digest/md5))

(defn redis-reader [pipe]
  (async/thread
    (loop [[marker, evt] (brpop)]
      (if (some? evt)
        (do
          (>!! pipe { :payload (handle-event evt) })
          (recur (brpop)))
        (>!! pipe { :payload :none })))))

(defn csv-writer [pipe]
  (async/thread
    (with-open [writer (io/writer (str "../output/clojure-" (now) ".csv"))]
      (loop []
        (let [{ :keys [payload] } (<!! pipe)]
          (if (= payload :none)
            (async/close! pipe)
            (do
              (csv/write-csv writer [[(now) (str (payload :index)) (signature payload)]])
              (recur))))))))

(defn run []
  (let [pipe (chan 1024)
        reader (redis-reader pipe)
        writer (csv-writer pipe)]
    (<!! (async/map vector [reader writer]))
    (println "Done.")))

(defn -main [& args] (run))
