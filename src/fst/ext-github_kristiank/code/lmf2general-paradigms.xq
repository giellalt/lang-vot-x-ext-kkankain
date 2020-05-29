xquery version "3.0" encoding "UTF-8";
import module namespace pjson = "http://keeleleek.ee/pextract/pjson" at "./karp-json.xqm";
import module namespace lmf = "http://keeleleek.ee/lmf" at "./lmf.xqm";
import module namespace giellatekno = "http://giellatekno.uit.no" at "./giellatekno.xqm";


(:~
 : This script is a proof-of-concept of the paradigm generalization method introduced in:
 : "A Computational Model for the Linguistic Notion of Morphological Paradigm" (Silfverberg, Miikka, Ling Liu & Mans Hulden. 2018)
 : 
 : @author Kristian Kankainen
 : @date 2018
 : @version 1.0
 :)

(: Read in the LMF :)
let $lmf := doc("../data/lmf.xml")

(: generalize all morphological patterns :)
let $general-morphological-patterns := $lmf//MorphologicalPattern ! lmf:get-general-morphological-pattern(.)

(: filter out distinct (unique) patterns :)
let $distinct-morphological-patterns :=
  for $pattern at $position in $general-morphological-patterns
    let $rest-of-generalpatterns := $general-morphological-patterns[position() > $position]
    return
    (: if there is another equal pattern in the rest :)
    if  ($rest-of-generalpatterns[deep-equal($pattern/TransformSet, ./TransformSet)])
    (: then don't return the pattern :)
    then()
    (: but if this is the only unique pattern, then return it :)
    else($pattern)

    
(: count general paradigms :)
let $num-of-distinct-patterns := count($distinct-morphological-patterns)

(: optimization :)
let $lexical-entries-and-their-general-pattern := 
  for $lexical-entry in $lmf//LexicalEntry
    return
    copy $new-entry := $lexical-entry
    modify (
      let $lemma := $lexical-entry/Lemma/feat[@att="writtenForm"]/@val/data()
      let $id := $lexical-entry/@morphologicalPatterns/data()
      let $lexical-entry-general-pattern :=
            lmf:get-morphologicalpattern-by-id(
              $lexical-entry/@morphologicalPatterns/data(),
              $lmf/LexicalResource
            )[1] => lmf:get-general-morphological-pattern()
      return insert node $lexical-entry-general-pattern into $new-entry
    )
    return $new-entry

(: group paradigms that share general patterns and show their IDs :)
let $instantiations-of-general-patterns :=
  for $general-pattern in $distinct-morphological-patterns
    let $lexical-entries := 
      for $lexical-entry in $lexical-entries-and-their-general-pattern
        let $lemma := $lexical-entry/Lemma/feat[@att="writtenForm"]/@val/data()
        let $pattern-id := $lexical-entry/@morphologicalPatterns/data()
        
        return if  (deep-equal(
                      $lexical-entry//TransformSet,
                      $general-pattern/TransformSet))
               then($lemma)
               else()

    return string-join((count($lexical-entries), $lexical-entries), ", ")

return string-join(($num-of-distinct-patterns,
                    $instantiations-of-general-patterns),
                    out:nl() || out:nl()
                  )
