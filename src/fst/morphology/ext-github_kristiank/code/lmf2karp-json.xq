xquery version "3.0" encoding "UTF-8";
import module namespace pjson = "http://keeleleek.ee/pextract/pjson" at "./karp-json.xqm";

(:~
 : This is a one-off script that converts LMF into Karp's json data used
 : in the Morfologilabbet app. It is meant for a one-time upload of data.
 :
 : @author Kristian Kankainen
 : @version 1.0
 :)

let $lmf := doc("../data/lmf.xml")
let $lexicon-name := "votiska"

let $lexicon-path   := "/home/kristian/Projektid/MA-thesis/data/karp-json-upload/"|| $lexicon-name ||".json"
let $paradigms-path := "/home/kristian/Projektid/MA-thesis/data/karp-json-upload/"|| $lexicon-name ||"paradigms.json"


(: Create lexicon json :)
let $lexicon := map { $lexicon-name : 
  array {
    for $entry in $lmf//LexicalEntry
      let $baseform := $entry//Lemma/feat[@att="writtenForm"]/@val/data()
      let $partofspeech := $entry/feat[@att="partOfSpeech"]/@val/data()
      let $lemgram := concat($baseform, "..nn.1")
      let $paradigm := $entry/@morphologicalPatterns/data()
      return map {
        "baseform": $baseform,
        "partOfSpeech": $partofspeech,
        "lemgram": $lemgram,
        "lexiconName": $lexicon-name,
        "paradigm" : $paradigm,
        "WordForms": array {
            for $wordform in $entry/WordForm
              let $writtenform := $wordform/feat[@att="writtenForm"]/@val/data()
              let $poses := ($wordform/feat[starts-with(@att, "grammatical")]/@val/data())
              let $msd := string-join($poses, " ")
              return map { 
                "msd": $msd,
                "writtenForm": $writtenform
              }
        }
      }
  }
}


(: Create lexicon json :)
let $paradigms := map { $lexicon-name||"paradigms" : 
  array {
    for $paradigm in $lmf//MorphologicalPattern
      let $id := $paradigm/feat[@att="id"]/@val/data()
      let $name := (substring($id, 3) => lower-case())
      return map {
        "MorphologicalPatternID": $id,
        "TransformCategory": map {},
        "TransformSet": array {
            for $transformset in $paradigm/TransformSet
              let $poses := ($transformset/GrammaticalFeatures/feat/@val/data())
              let $msd := string-join($poses, " ")
              return 
                map {
                  "GrammaticalFeatures" : map {"msd": $msd},
                  "Process": array {
                    for $process in $transformset/Process
                      return map:merge (
                        for $process-step in $process/feat
                          return map:entry(
                            $process-step/@att/data(), $process-step/@val/data()
                          )
                      )
                  },
                  "VariableInstances": array {
                    for $instanceset in $paradigm/AttestedParadigmVariableSets/AttestedParadigmVariableSet
                      return map:merge(
                        for $instance in $instanceset/feat
                          return (
                            (:map:entry("first-attest", concat($name, "..nn.1")),:)
                            map:entry($instance/@att/data(), $instance/@val/data())
                          )
                      )
                  },
                  (:"_entries": 3,
                  "_lexiconName": "votiskaparadigms",
                  "_partOfSpeech": "nn",
                  "_uuid": "51279fca-3e77-11e8-b8be-94659c6b3e9c",
                  "lexiconName": "votiskaparadigms":)
                  "_partOfSpeech": "nn",
                  "_lexiconName": $lexicon-name||"paradigms",
                  "lexiconName":  $lexicon-name||"paradigms"
                }
                
              
        }
      }
  }
}

let $lexicon-json   := json:serialize($lexicon,   map { 'format': 'xquery' })
let $paradigms-json := json:serialize($paradigms, map { 'format': 'xquery' })

(: write to files :)
return (
  file:write-text($lexicon-path, $lexicon-json),
  file:write-text($paradigms-path, $paradigms-json)
)