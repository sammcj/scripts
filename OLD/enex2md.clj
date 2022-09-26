;;; This script by Paul Biggar, available at https://gist.github.com/pbiggar/6323088a31d689c61a24
;;;
;;; This converts Evernote files into plaintext (not really markdown), so you can move your stuff out of evernote into a markdown editor.
;;;
;;; First, export your Evernotes, using File -> export notes. Export them into "My Notes.enex".
;;; copy this file into the same direcory as "My Notes.enex".
;;;
;;; To run this file, you'll need some dependencies, but they should only take a moment to install.
;;;   leinigen: On OSX, use "brew install leiningen".
;;;   lein-exec: From the terminal, run `mkdir ~/.lein; echo '{:user {:plugins [[lein-exec "0.3.5"]]}}' > ~/.lein/profiles.clj
;;;
;;; Now to run it:
;;;   lein exec enex2md.clj
;;;
;;; You should now have a file for each note, called "note_title.md". (spaces, etc, removed from the filename)
;;; This will remove much of the formatting, but may leave some in so I would check the files out.

(require '[clojure.xml])
(import '[java.text SimpleDateFormat Normalizer]
        '[java.io File]
        '[java.util TimeZone])


(defn convert [xml]

  (let [lines (clojure.string/split-lines xml)
        lines (drop 3 lines)
        lines (drop-last lines)
        lines (for [l lines]
                (-> l
                    (clojure.string/replace #"\s*<div>" "")
                    (clojure.string/replace #"</div>\s*" "")
                    (clojure.string/replace #"<span.*?>" "")
                    (clojure.string/replace #"</span>" "")
                    (clojure.string/replace #"<tt.*?>" "")
                    (clojure.string/replace #"</tt>" "")
                    (clojure.string/replace "<br/>" "")))
        output  (-> (clojure.string/join "\n" lines)
                    (clojure.string/replace #"\n{2,}" "\n\n")
                    (Normalizer/normalize java.text.Normalizer$Form/NFKD)
                    (clojure.string/replace "&lt;" "<")
                    (clojure.string/replace "&gt;" "<")
                    (clojure.string/replace "&amp;" "&")
                    (clojure.string/replace "&apos;" "'")
                    (clojure.string/replace "&quot;" "\"")
                    (clojure.string/replace "“" "\"")
                    (clojure.string/replace "”" "\"")
                    (clojure.string/replace #"^\n" ""))]
    output))

(defn x []
  (let [notes (-> "My Notes.enex" clojure.xml/parse :content)]
    (doseq [n notes]
      (let [n (:content n)
            n (into {}
                    (map #(vec [(:tag %) (:content %)]) n))
            df (SimpleDateFormat. "yyyyMMdd'T'HHmmss'Z'")
            _ (.setTimeZone df (TimeZone/getTimeZone "UTC")) ;
            timestamp (->> n :updated first (.parse df) .getTime)
            filename (str (-> n
                              :title
                              first
                              .toLowerCase
                              (clojure.string/replace #"[\/ \-]" "_")
                              (clojure.string/replace #"['?’,!\"\+:\(\)\[\]]" "")
                              (clojure.string/replace #"_+" "_"))
                          ".txt")]
        (println filename)
        (spit filename (-> n :content first convert doall))
        (.setLastModified (File. filename) timestamp)))))


(x)
