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
        discount (discounts (evt :wday))
        percent (/ discount 100)
        ratio (- 1 percent)]
    (round (* price ratio))))

(defn transform-event [evt]
  (let [parsed (json/read-str evt :key-fn keyword)
        total (calc-total parsed)
        index (parsed :index)
        updated (assoc parsed :total total)
        encoded (json/write-str updated)
        signature (digest/md5 encoded)]
    [(now) (str index) signature]))

(defn redis-reader [pipe]
  (async/thread
    (loop []
      (let [[marker, evt] (brpop)]
        (if (some? evt)
          (do
            (>!! pipe evt)
            (recur)))))
    :done))

(defn csv-writer [pipe]
  (async/thread
    (with-open [writer (io/writer (str "../output/clojure-" (now) ".csv"))]
      (loop []
        (let [row (<!! pipe)]
          (if (some? row)
            (do
              (csv/write-csv writer [row])
              (recur))))))
    :done))

(defn spawn-readers [pipe]
  (doall
    (map
      (fn [_](redis-reader pipe))
      (repeat 4 :reader))))

(defn run []
  (let [pipe (chan 1024 (map transform-event))
        readers (spawn-readers pipe)
        writer (csv-writer pipe)]
    (<!! (async/map vector readers))
    (println "Readers Done...")
    (async/close! pipe)
    (<!! writer)
    (println "Writer Done...")))

(defn -main [& args] (run))
