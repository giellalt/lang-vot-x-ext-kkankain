xquery version "3.0" encoding "UTF-8";

(:~
 : This script converts the themeforms table into a format suitable for pextract.
 : More about pextract here: https://github.com/marfors/paradigmextract/
 : 
 : @author Kristian Kankainen
 : @date 2019
 : @version 1.0
 :)

(: Read in the theme forms table :)
let $csv-file    := file:read-text("data/wordforms.csv")
let $csv-options := map { 'header': true() }
let $csv := csv:parse($csv-file, $csv-options)

(: State our output MSD labels (in same order as they appear in the CSV table) :)
let $MSDs := (
  "grammaticalNumber=singular,grammaticalCase=nominative",
  "grammaticalNumber=singular,grammaticalCase=genitive",
  "grammaticalNumber=singular,grammaticalCase=partitive",
  "grammaticalNumber=singular,grammaticalCase=illative",
  "grammaticalNumber=singular,grammaticalCase=inessive",
  "grammaticalNumber=singular,grammaticalCase=elative",
  "grammaticalNumber=singular,grammaticalCase=allative",
  "grammaticalNumber=singular,grammaticalCase=adessive",
  "grammaticalNumber=singular,grammaticalCase=ablative",
  "grammaticalNumber=singular,grammaticalCase=translative",
  "grammaticalNumber=singular,grammaticalCase=terminative",
  "grammaticalNumber=singular,grammaticalCase=comitative",
  "grammaticalNumber=plural,grammaticalCase=nominative",
  "grammaticalNumber=plural,grammaticalCase=genitive",
  "grammaticalNumber=plural,grammaticalCase=partitive",
  "grammaticalNumber=plural,grammaticalCase=illative",
  "grammaticalNumber=plural,grammaticalCase=inessive",
  "grammaticalNumber=plural,grammaticalCase=elative",
  "grammaticalNumber=plural,grammaticalCase=allative",
  "grammaticalNumber=plural,grammaticalCase=adessive",
  "grammaticalNumber=plural,grammaticalCase=ablative",
  "grammaticalNumber=plural,grammaticalCase=translative",
  "grammaticalNumber=plural,grammaticalCase=terminative",
  "grammaticalNumber=plural,grammaticalCase=comitative"
)

(: Convert each CSV record into appropriate format, see the output file for format :)
let $pextract-records :=
    for $csv-record in $csv/csv/record
      let $pextract-record :=
          for $msd at $enum in $MSDs
            let $wordform := $csv-record/*[$enum]
            return concat($wordform, out:tab(), $msd)
      return string-join($pextract-record, out:nl())

(: Each record is delimited by an empty row :)
let $pextract := string-join($pextract-records, out:nl() || out:nl())

(: Save it in the output file :)
return file:write-text("data/pextract/vot-commonNoun", $pextract)