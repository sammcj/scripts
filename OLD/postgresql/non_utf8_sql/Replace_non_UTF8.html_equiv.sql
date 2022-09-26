-- SELECT remove_non_utf8(column6_text) FROM table101;

CREATE OR REPLACE FUNCTION remove_non_utf8(p_string IN VARCHAR, show_arg IN boolean DEFAULT true )
  RETURNS character varying AS
$BODY$
DECLARE
  v_string VARCHAR;
  last_string VARCHAR;
BEGIN 
  v_string := p_string;
  last_string := '';
  IF show_arg THEN
     RAISE INFO 'running remove_non_utf8 (%...%)', left(v_string,10), right(v_string,10);
  END IF;

  -- The following substitutions will not handle more that a one-off bad byte
  -- They need to be re-applied until v_string stops changing
  -- They can be safely applied to any UTF8 text

  WHILE last_string != v_string LOOP

    last_string := v_string;

    -- Specific substitutions  xFE-xFF
    v_string := regexp_replace(v_string, 
  	E'\xFF' , 'ÿ' , 'g'); 
  
    -- Specific substitutions  x80-xBF
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\x85'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1…' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\x8A'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1Š' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\x91'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1‘' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\x92'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1’' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\x93'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1“' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\x94'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1”' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\x95'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1•' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\x96'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1–' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\x97'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1—' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '[\xA0\xAD]'                       -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1 ' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xA3'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1£' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xA7'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1§' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xAB'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1«' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xAC'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1¬' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xB7'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1·' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xB8'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1¸' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xB9'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1¹' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xBA'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1º' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xBB'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1»' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xBC'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1¼' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xBD'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1½' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xBE'                             -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1¾' , 'g');
  
    -- Specific substitutions  xC0-xDF
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xC3([\x01-x7F\xC0-\xFF]|$)'      -- replace 0xC0-0xDF - only valid if followed by 0x80-0xBF
  	 , '\1Ã\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xC4([\x01-x7F\xC0-\xFF]|$)'      -- replace 0xC0-0xDF - only valid if followed by 0x80-0xBF
  	 , '\1Ä\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xC5([\x01-x7F\xC0-\xFF]|$)'      -- replace 0xC0-0xDF - only valid if followed by 0x80-0xBF
  	 , '\1Å\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xC6([\x01-x7F\xC0-\xFF]|$)'      -- replace 0xC0-0xDF - only valid if followed by 0x80-0xBF
  	 , '\1Æ\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xC7([\x01-x7F\xC0-\xFF]|$)'      -- replace 0xC0-0xDF - only valid if followed by 0x80-0xBF
  	 , '\1Ç\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xC8([\x01-x7F\xC0-\xFF]|$)'      -- replace 0xC0-0xDF - only valid if followed by 0x80-0xBF
  	 , '\1È\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xC9([\x01-x7F\xC0-\xFF]|$)'      -- replace 0xC0-0xDF - only valid if followed by 0x80-0xBF
  	 , '\1É\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xD0([\x01-x7F\xC0-\xFF]|$)'      -- replace 0xC0-0xDF - only valid if followed by 0x80-0xBF
  	 , '\1Ð\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xD5([\x01-x7F\xC0-\xFF]|$)'      -- replace 0xC0-0xDF - only valid if followed by 0x80-0xBF
  	 , '\1Õ\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xD8([\x01-x7F\xC0-\xFF]|$)'      -- replace 0xC0-0xDF - only valid if followed by 0x80-0xBF
  	 , '\1Ø\2' , 'g');
  
    -- Specific substitutions  xE0-xEF
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xE0([\x80-\xBF]{0,1}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xE0-0xEF if invalid UTF8 char
  	 , '\1à\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xE1([\x80-\xBF]{0,1}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xE0-0xEF if invalid UTF8 char
  	 , '\1á\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xE2([\x80-\xBF]{0,1}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xE0-0xEF if invalid UTF8 char
  	 , '\1â\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xE7([\x80-\xBF]{0,1}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xE0-0xEF if invalid UTF8 char
  	 , '\1ç\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xE9([\x80-\xBF]{0,1}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xE0-0xEF if invalid UTF8 char
  	 , '\1é\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xED([\x80-\xBF]{0,1}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xE0-0xEF if invalid UTF8 char
  	 , '\1í\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xEF([\x80-\xBF]{0,1}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xE0-0xEF if invalid UTF8 char
  	 , '\1ï\2' , 'g');
  
    -- Specific substitutions  xF0-xF7
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xF2([\x80-\xBF]{0,2}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xF0-0xF7 if invalid
  	 , '\1ò\2' , 'g');
  
    -- Specific substitutions  xF8-xFB
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xFA([\x80-\xBF]{0,3}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xF8-0xFB if invalid
  	 , '\1ú\2' , 'g');
  
    -- Specific substitutions  xFC-xFD
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xFC([\x80-\xBF]{0,2}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xFC-0xFD if invalid
  	 , '\1ü\2' , 'g');
  
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '\xFD([\x80-\xBF]{0,2}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xFC-0xFD if invalid
  	 , '\1ý\2' , 'g');
  
  END LOOP; -- last_string != v_string
  --
  -- Again for the default subsitution of _ (underscore)
  --
  last_string := '';

  WHILE last_string != v_string LOOP

    last_string := v_string;

    -- xFE and xFF are not currently valid UTF8 for 1st or subsequent bytes
    v_string := regexp_replace(v_string, 
  	E'[\xFE\xFF]' , '_' , 'g');
  
    -- RAISE NOTICE 'Fix UTF8 continuation byte 80-BF in text: %', v_string;
  
    -- Catch single 80-BF - is not valid UTF8 on it's own
    -- ( ASCII or UTF8 or empty )  0x80-0xBF  ( ASCII or 0xC0-0xFF )
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                  -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '[\x80-\xBF]'                     -- replace 0x80-0xBF - not valid as 1st byte of UTF8 sequence,
  	 , '\1_' , 'g');
  
    -- RAISE NOTICE 'Fix UTF8 2 byte C0-DF in text: %', v_string;
  
    -- Broken 2-byte UTF8 C0-DF
    -- ( ASCII or UTF8 or empty )  0x80-0xDF  ( ASCII or 0xC0-0xFF )
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '[\xC0-\xDF]([\x01-x7F\xC0-\xFF]|$)'  -- replace 0xC0-0xDF - only valid if followed by 0x80-0xBF
  	 , '\1_\2' , 'g');
  
    -- RAISE NOTICE 'Fix UTF8 3 byte E0-EF in text: %', v_string;
  
    -- Broken 3-byte UTF8 E0-EF
    -- ( ASCII or UTF8 or empty )  0xE0-0xDF  ( ASCII or 0xC0-0xFF )
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '[\xE0-\xEF]([\x80-\xBF]{0,1}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xE0-0xEF if invalid UTF8 char
  	 , '\1_\2' , 'g');
  
    -- RAISE NOTICE 'Fix UTF8 4 byte F0-F7 in text: %', v_string;
  
    -- Broken 4-byte UTF8 F0-F7
    -- ( ASCII or UTF8 or empty )  0x80-0xDF  ( ASCII or 0xC0-0xFF )
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '[\xF0-\xF7]([\x80-\xBF]{0,2}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xF0-0xF7 if invalid
  	 , '\1_\2' , 'g');
  
    -- RAISE NOTICE 'Fix UTF8 5 byte F8-FB in text: %', v_string;
  
    -- Broken 5-byte UTF8 F8-FB
    -- ( ASCII or UTF8 or empty )  0x80-0xDF  ( ASCII or 0xC0-0xFF )
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '[\xF8-\xFB]([\x80-\xBF]{0,3}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xF8-0xFB if invalid
  	 , '\1_\2' , 'g');
  
    -- RAISE NOTICE 'Fix UTF8 6 byte FC-FD in text: %', v_string;
  
    -- Broken 6-byte UTF8 FC-FD
    -- ( ASCII or UTF8 or empty )  0x80-0xDF  ( ASCII or 0xC0-0xFF )
    v_string := regexp_replace(v_string, 
  	E'(^|[\x01-\x7F]|'                   -- ASCII or empty
           '[\xC0-\xDF][\x80-\xBF]|'          -- 2 byte UTF8
           '[\xE0-\xEF][\x80-\xBF]{2}|'       -- 3 byte UTF8
           '[\xF0-\xF7][\x80-\xBF]{3}|'       -- 4 byte UTF8
           '[\xF8-\xFB][\x80-\xBF]{4}|'       -- 5 byte UTF8
           '[\xFC-\xFD][\x80-\xBF]{5})'       -- 6 byte UTF8
           '[\xFC-\xFD]([\x80-\xBF]{0,2}[\x01-x7F\xC0-\xFF]|$)'   -- replace 0xFC-0xFD if invalid
  	 , '\1_\2' , 'g');
  
  END LOOP; -- last_string != v_string

-- Invalid sequences:
-- ASCII  80-FF ASCII | C0-FF  -> excludes 80-BF 80-BF .... hmmm
-- ASCII  C0-DF ASCII | C0-FF  -> exclude C0-DF  80-BF
-- ASCII  E0-EF 80-BF {0,1} ASCII | C0-FF  -> exclude E0-EF  80-BF  80-BF
-- ASCII  F0-F7 80-BF {0,2} ASCII | C0-FF  -> exclude F0-F7  80-BF  80-BF  80-BF
-- ASCII  F8-FB 80-BF {0,3} ASCII | C0-FF  -> exclude F8-FB  80-BF  80-BF  80-BF  80-BF
-- ASCII  FC-FD 80-BF {0,4} ASCII | C0-FF  -> exclude FC-FD  80-BF  80-BF  80-BF  80-BF  80-BF
--  80-BF ? 

   RETURN v_string;
END
$BODY$  LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION process_non_utf8_at_column( p_table_name IN VARCHAR,
                                                       p_column_name IN VARCHAR)
  RETURNS VOID AS
$BODY$
DECLARE 
  v_utf8_string_filter CONSTANT VARCHAR = '(' || '''' || '^(' || '''' || '||$$[\09\0A\0D\x20-\x7E]|$$|| $$[\xC2-\xDF][\x80-\xBF]|$$||  $$\xE0[\xA0-\xBF][\x80-\xBF]|$$|| $$[\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}|$$||  $$\xED[\x80-\x9F][\x80-\xBF]|$$||$$\xF0[\x90-\xBF][\x80-\xBF]{2}|$$||$$[\xF1-\xF3][\x80-\xBF]{3}|$$||$$\xF4[\x80-\x8F][\x80-\xBF]{2}$$||' ||
  '''' || ')*$' || '''' ||')';   
  n_max_chunks BIGINT;
  ctid_row RECORD;
  i_num INTEGER;
BEGIN
  EXECUTE 'DROP TABLE IF EXISTS x_list;';
  
  EXECUTE 'CREATE TEMPORARY TABLE x_list ( ' ||
          ' rid TID NOT NULL, ' ||
          ' row_value NUMERIC(11,2) NOT NULL, ' ||
          ' row_message character varying, ' ||
          ' row_chunk bigint ) ON COMMIT DELETE ROWS; ';
  
  EXECUTE 'CREATE INDEX chunk_idx ON x_list (row_chunk);';

  EXECUTE FORMAT(' INSERT INTO X_LIST (rid, row_value, row_message, row_chunk) ' ||
                 ' SELECT ctid, Row_Number() Over(), %I,' || 
                 ' (Row_Number() Over())/50000 + 1 As row_chunk ' ||
                 ' FROM %I', p_column_name, p_table_name);

  EXECUTE 'SELECT MAX(row_chunk) FROM x_list' INTO n_max_chunks;

  FOR i_num IN 1..n_max_chunks
  LOOP
 
      RAISE NOTICE '%: table: %    (column: %) time: %', i_num, p_table_name, p_column_name, clock_timestamp();
      FOR ctid_row IN EXECUTE FORMAT('SELECT rid FROM x_list WHERE row_chunk = $1 AND NOT %I ~ $2', 'row_message') 
                USING i_num, v_utf8_string_filter FOR UPDATE
      LOOP
        EXECUTE FORMAT('UPDATE %I SET %I = remove_non_utf8(cast(%I as text),true) WHERE ctid = $1 AND %I ~ E''[\x80-\xFF]'' AND cast(%I as text) != remove_non_utf8(cast(%I as text),false)', p_table_name, p_column_name, p_column_name, p_column_name, p_column_name, p_column_name) USING ctid_row.rid;
      END LOOP;
      RAISE NOTICE '%: table: %    (column: %) time: %', i_num, p_table_name, p_column_name, clock_timestamp();

  END LOOP;

  EXECUTE 'DROP TABLE IF EXISTS x_list;';
  
END
$BODY$  LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_non_utf8_at_schema(p_my_schema IN VARCHAR)
RETURNS VOID AS
$BODY$
DECLARE 
  cur_column RECORD;
  num_rows BIGINT;
BEGIN
  -- Loop through all character columns in target schema
  FOR cur_column IN SELECT table_name, column_name 
                    FROM information_schema.columns  
                    WHERE table_schema = p_my_schema AND NOT ( table_name = 'spatial_ref_sys' OR table_name = 'geography_columns' OR table_name = 'geometry_columns' )
                      AND (data_type  LIKE 'character%' OR data_type LIKE 'text%' OR data_type LIKE 'varchar%')
  LOOP   
    EXECUTE FORMAT('SELECT count(*) FROM %I', cur_column.table_name ) INTO num_rows;
    IF ( num_rows > 0 ) THEN
      RAISE NOTICE 'Processing table: %  	column: %		time: %', cur_column.table_name, cur_column.column_name, clock_timestamp();
      PERFORM process_non_utf8_at_column(cur_column.table_name, cur_column.column_name); 
      RAISE NOTICE 'return from function time: %', clock_timestamp();
    ELSE
      RAISE NOTICE 'Processing table: %  	(empty table skipping)', cur_column.table_name;
    END IF;
  END LOOP;
END
$BODY$  LANGUAGE plpgsql;


--
-- The following function seeks out the offending schema/table/column/row and returns these as a table
--
-- DROP FUNCTION IF EXISTS search_for_non_utf8_columns(search_tables name[], search_schema name[], show_timestamps boolean);

CREATE OR REPLACE FUNCTION search_for_non_utf8_columns(
    search_tables name[] default '{}',
    search_schema name[] default '{public}',
    show_timestamps boolean default true
)
RETURNS table(schemaname text, tablename text, columnname text, hits integer)
AS $BODY$
BEGIN
  FOR schemaname,tablename,columnname IN
      SELECT c.table_schema,c.table_name,c.column_name
      FROM information_schema.columns c
      JOIN information_schema.tables t ON
        (t.table_name=c.table_name AND t.table_schema=c.table_schema)
      WHERE (c.table_name=ANY(search_tables) OR search_tables='{}')
        AND c.table_schema=ANY(search_schema)
        AND t.table_type='BASE TABLE'
        AND (data_type  LIKE 'character%' OR data_type LIKE 'text%' OR data_type LIKE 'varchar%')
  LOOP
    IF show_timestamps THEN
      RAISE INFO 'schema: %		table: %		column: %		time: %', schemaname, tablename, columnname, clock_timestamp();
    END IF;
    EXECUTE format('SELECT count(*) FROM %I.%I WHERE cast(%I as text) ~  E''[\x80-\xFF]'' AND cast(%I as text) != remove_non_utf8(cast(%I as text),false)',
       schemaname,
       tablename,
       columnname,
       columnname,
       columnname
    ) INTO hits;
    IF hits > 0 THEN
      RETURN NEXT;
    END IF;
 END LOOP;
END;
$BODY$ language plpgsql;

