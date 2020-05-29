xquery version "3.0" encoding "UTF-8";
module namespace pjson = "http://keeleleek.ee/pextract/pjson";
declare namespace map  = "http://www.w3.org/2005/xpath-functions/map";
declare namespace json = "http://basex.org/modules/json";

(:~
 : This module provides the basic functionality to read and extract
 : information from the lexical tool Karp's json exports.
 :
 : It mainly provides conversion to Lexical Markup Framework XML.
 :
 : @author Kristian Kankainen
 : @version 1.0
 :)


(:~
 : Represents a map with variable instances as an AttestedParadigmVariableSet
 : element.
 : 
 : @since 1.0
 :)
declare function pjson:variable-instance-to-lmf($variableinstance as map(*)) {
  <AttestedParadigmVariableSet>
    {
     map:for-each($variableinstance, function($k,$v) {
               <feat att='{$k}' val='{$v}'/>
             }
       )
    }
  </AttestedParadigmVariableSet>
};


(:~
 : Represents a paradigm map as a LMF MorphologicalPattern.
 :
 : @since 1.0
 :)
declare function pjson:paradigm-map-to-lmf($paradigm) {
  <MorphologicalPattern>
    <feat att="id" val='{$paradigm?("MorphologicalPatternID")}'/>
    <feat att="partOfSpeech" val='{$paradigm?("_partOfSpeech")}'/>
    <AttestedParadigmVariableSets>
      {$paradigm?("VariableInstances")?* ! pjson:variable-instance-to-lmf(.)}
    </AttestedParadigmVariableSets>
    {
    (: iterate the array of TransformSet maps :)
    for $transformset in $paradigm?("TransformSet")?*
      let $msds := $transformset?("GrammaticalFeatures")?("msd") => tokenize()
      return
        <TransformSet>
          <GrammaticalFeatures>
            <feat att="grammaticalNumber" val="{$msds[1]}"/>
            <feat att="grammaticalCase" val="{$msds[2]}"/>
          </GrammaticalFeatures>
          {
          (: iterate the array of Process maps :)
          for $process in $transformset?("Process")?*
            return
              <Process>
              {
              (: this keeps the feat-elements in the correct order :)
              for $possible-key in ("operator", "processType", "variableNum", "stringValue")
                return
                  if(map:contains($process, $possible-key))
                  then(<feat att="{$possible-key}" val="{$process?($possible-key)}"/>)
                  else()
              }
              </Process>
          }
        </TransformSet>
    }
  </MorphologicalPattern>
};


(:~
 : Simple translation table holding Giellatekno specific vocabulary.
 : 
 : @since 1.0
 :)
declare function pjson:get-giellatekno-msd($msd-string as xs:string) {
  let $msds := tokenize($msd-string)
  let $translate := map {
    "singular":    "sg",
    "plural":      "pl",
    "nominative":  "nom",
    "genitive":    "gen",
    "partitive":   "par",
    "illative":    "ill",
    "inessive":    "ine",
    "elative":     "ela",
    "adessive":    "ade",
    "ablative":    "abl",
    "allative":    "all",
    "translative": "tra",
    "terminative": "ter",
    "comitative":  "com"
  }
  return (: string-join( :)
    for $msd in $msds
      return ($translate?($msd), $msd)[1]
  (: , " ") :)
};


(:~
 : Represents an array as WordForm elements.
 : 
 : @since 1.0
 :)
declare function pjson:wordforms-to-lmf($array as array(map(xs:string,xs:string)*)) {
  $array?* !
      ((: if pos = noun :)
      (: let $msds := pjson:get-giellatekno-msd(.?("msd")) :)
      let $msds := tokenize(.?("msd"))
      return 
    <WordForm>
      <feat att="writtenForm" val='{.?("writtenForm")}' />
      <feat att="msd" val='{.?("msd")}' />
      <feat att="grammaticalNumber" val="{$msds[1]}" />
      <feat att="grammaticalCase" val="{$msds[2]}" />
    </WordForm>
          )
};


(:~
 : Represents a map as a LexicalEntry element.
 : 
 : @since 1.0
 :)
declare function pjson:lexicalentry-map-to-lmf($lexicalentry as map(*)) {
  <LexicalEntry morphologicalPatterns='{string-join(($lexicalentry?("paradigm")), " ")}'>
    <feat att="partOfSpeech" val='{$lexicalentry?("partOfSpeech")}'/>
    <feat att="karp-lemgram" val='{$lexicalentry?("lemgram")}'/>
    <Lemma>
      <feat att="writtenForm" val='{$lexicalentry?("baseform")}' />
    </Lemma>
    {$lexicalentry?("WordForms") ! pjson:wordforms-to-lmf(.)}
  </LexicalEntry>
};


(:~
 : Represents an entire Karp json as a LMF LexicalResource.
 : 
 : @since 1.0
 :)
declare function pjson:karp-pjson2lmf($lexicon-json, $paradigms-json) {
  let $json-paradigms := json-doc($paradigms-json)
  let $json-lexicon   := json-doc($lexicon-json)
  
  let $lmf := 
  <LexicalResource>
    <Lexicon>
      <GlobalInformation>
        <feat att="label"   val="LMF representation of the Votic resource created with Karp and Extract Morphology Laboratory"/>
        <feat att="comment" val="The morphological paradigms has been extracted with the pextract tool."/>
        <feat att="author"  val="Kristian Kankainen"/>
        <feat att="languageCoding" val="ISO 639-3"/>
      </GlobalInformation>
      <feat att="language"  val="vot" />
      {(: morphological patterns section:)
      $json-paradigms?("votiskaparadigms")?* ! pjson:paradigm-map-to-lmf(.),
      (: lexical entries section :)
      $json-lexicon?("votiska")?* ! pjson:lexicalentry-map-to-lmf(.)
      }
    </Lexicon>
  </LexicalResource>
  
  return $lmf
};
