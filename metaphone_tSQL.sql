-- This SQL implements the Double Metaphone algorythm (c) 1998, 1999 by Lawrence Philips
-- it was translated to Python, and then to SQL from the C source written by Kevin Atkinson (http://aspell.net/metaphone/)
-- By Andrew Collins (atomodo.com) - Feb, 2007 who claims no rights to this work
-- github.com/AtomBoy/double-metaphone
-- Updated Nov 27, 2007 to fix a bug in the 'CC' section
-- Updated Jun 01, 2010 to fix a bug in the 'Z' section - thanks Nils Johnsson!
-- Updated Jun 25, 2010 to fix 16 signifigant bugs - thanks again Nils Johnsson for a spectacular
--   bug squashing effort. There were many cases where this function wouldn't give the same output
--   as the original C source that were fixed by his careful attention and excellent communication.
-- Ported to MS-SQL June 29, 2018.
--   Changed the size of input parameter, pri and sec variables. 
--   Added a return string variable to ensure we don't run out of space to contain the result of pri + sec. 
--   Tested on MS-SQL 2008 and above

--  Drop function if it already exists
if  exists  ( select 1 from sys.OBJECTS where OBJECT_ID = object_id ( '[dbo].[dbl_metaphone]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].dbl_metaphone
GO

CREATE Function [dbo].dbl_metaphone(
	@String VARCHAR(128)
)
RETURNS VARCHAR(128)

AS
BEGIN
	DECLARE @length INT, @first INT, @last INT, @pos INT, @prevpos INT, @is_slavo_germanic INT;
	DECLARE @pri VARCHAR(64), @sec VARCHAR(64), @retStr VARCHAR(128);
	DECLARE @ch CHAR;
	-- returns the double metaphone code OR codes for given string
	-- if there is a secondary dm it is separated with a semicolon
	-- there are no checks done on the input string, but it should be a single word OR name.
	--  @String is short for string. I usually prefer descriptive over short, but this var is used a lot!
	SET @first = 3;
	SET @length = len(@String);
	SET @last = @first + @length -1;
	SET @String = CONCAT(replicate('-', @first -1), upper(@String), replicate(' ', 5)); --  pad @String so we can index beyond the begining AND end of the input string
	SET @is_slavo_germanic = (select coalesce((select 1 where @String like '%W%' OR @String LIKE '%K%' OR @String LIKE '%CZ%'),0));  -- the check for '%W%' will catch WITZ
	SET @pos = @first; --  @pos is short for position
	
	-- skip these silent letters when at start of word
	IF SUBSTRING(@String, @first, 2) IN ('GN', 'KN', 'PN', 'WR', 'PS') 
		SET @pos = @pos + 1;
	
	--  Initial 'X' is pronounced 'Z' e.g. 'Xavier'
	IF SUBSTRING(@String, @first, 1) = 'X' 
		begin
			SET @pri = 'S'; 
			set @sec = 'S';
			set @pos = @pos  + 1; -- 'Z' maps to 'S'
		end

	--  main loop through chars IN @String
	WHILE @pos <= @last 
		begin
			-- print str(@pos) + '\t' + SUBSTRING(@String, @pos)
			SET @prevpos = @pos;
			SET @ch = SUBSTRING(@String, @pos, 1); --  @ch is short for character
			
			IF @ch IN ('A', 'E', 'I', 'O', 'U', 'Y') 
				BEGIN
					IF @pos = @first 
						begin --  all init vowels now map to 'A'
							SET @pri = CONCAT(@pri, 'A'); 
							set @sec = CONCAT(@sec, 'A'); 
							set @pos = @pos  + 1; -- nxt = ('A', 1)
						end
					ELSE
						SET @pos = @pos + 1;
				END
				
			ELSE IF @ch = 'B' 
				BEGIN
					-- '-mb', e.g', 'dumb', already skipped over... see 'M' below
					IF SUBSTRING(@String, @pos+1, 1) = 'B' 
						begin
							SET @pri = CONCAT(@pri, 'P'); 
							set @sec = CONCAT(@sec, 'P'); 
							set @pos = @pos  + 2; -- nxt = ('P', 2)
						end
					ELSE
						begin
							SET @pri = CONCAT(@pri, 'P'); 
							set @sec = CONCAT(@sec, 'P'); 
							set @pos = @pos  + 1; -- nxt = ('P', 1)
						END
				END
					
			ELSE IF @ch = 'C' 
				BEGIN
					--  various germanic
					IF (@pos > (@first + 1) AND SUBSTRING(@String, @pos-2, 1) NOT IN ('A', 'E', 'I', 'O', 'U', 'Y') 
											AND SUBSTRING(@String, @pos-1, 3) = 'ACH' 
											AND (SUBSTRING(@String, @pos+2, 1) NOT IN ('I', 'E') OR SUBSTRING(@String, @pos-2, 6) IN ('BACHER', 'MACHER'))) 
						begin
							SET @pri = CONCAT(@pri, 'K'); 
							set @sec = CONCAT(@sec, 'K'); 
							set @pos = @pos  + 2; -- nxt = ('K', 2)
						end
					--  special case 'CAESAR'
					ELSE if @pos = @first AND SUBSTRING(@String, @first, 6) = 'CAESAR' 
						begin
							SET @pri = CONCAT(@pri, 'S'); 
							set @sec = CONCAT(@sec, 'S'); 
							set @pos = @pos  + 2; -- nxt = ('S', 2)
						end
					ELSE IF SUBSTRING(@String, @pos, 4) = 'CHIA' -- italian 'chianti'
						begin
							SET @pri = CONCAT(@pri, 'K'); 
							set @sec = CONCAT(@sec, 'K'); 
							set @pos = @pos  + 2; -- nxt = ('K', 2)
						end
					ELSE IF SUBSTRING(@String, @pos, 2) = '@ch' --  find 'michael'
						begin
							IF @pos > @first AND SUBSTRING(@String, @pos, 4) = 'CHAE' 
								begin
									SET @pri = CONCAT(@pri, 'K'); 
									set @sec = CONCAT(@sec, 'X'); 
									set @pos = @pos  + 2; -- nxt = ('K', 'X', 2)
								end
							ELSE IF @pos = @first AND (SUBSTRING(@String, @pos+1, 5) IN ('HARAC', 'HARIS') 
												OR SUBSTRING(@String, @pos+1, 3) IN ('HOR', 'HYM', 'HIA', 'HEM')) 
												AND SUBSTRING(@String, @first, 5) != 'CHORE' 
								begin
									SET @pri = CONCAT(@pri, 'K'); 
									set @sec = CONCAT(@sec, 'K'); 
									set @pos = @pos  + 2; -- nxt = ('K', 2)
								end
							-- germanic, greek, OR otherwise '@ch' for 'kh' sound
							ELSE IF SUBSTRING(@String, @first, 4) IN ('VAN ', 'VON ') 
										OR SUBSTRING(@String, @first, 3) = 'SCH'
										OR SUBSTRING(@String, @pos-2, 6) IN ('ORCHES', 'ARCHIT', 'ORCHID')
										OR SUBSTRING(@String, @pos+2, 1) IN ('T', 'S')
										OR ((SUBSTRING(@String, @pos-1, 1) IN ('A', 'O', 'U', 'E') OR @pos = @first)
										AND SUBSTRING(@String, @pos+2, 1) IN ('L', 'R', 'N', 'M', 'B', 'H', 'F', 'V', 'W', ' ')) 
								begin
									SET @pri = CONCAT(@pri, 'K'); 
									set @sec = CONCAT(@sec, 'K'); 
									set @pos = @pos  + 2; -- nxt = ('K', 2)
								end 
							ELSE
								IF @pos > @first 
									IF SUBSTRING(@String, @first, 2) = 'MC' 
										begin
											SET @pri = CONCAT(@pri, 'K'); 
											set @sec = CONCAT(@sec, 'K'); 
											set @pos = @pos  + 2; -- nxt = ('K', 2)
										end
									ELSE
										begin
											SET @pri = CONCAT(@pri, 'X'); 
											set @sec = CONCAT(@sec, 'K'); 
											set @pos = @pos  + 2; -- nxt = ('X', 'K', 2)
										end	
								ELSE
									begin
										SET @pri = CONCAT(@pri, 'X'); 
										set @sec = CONCAT(@sec, 'X'); 
										set @pos = @pos  + 2; -- nxt = ('X', 2)
									end
						end
					-- e.g, 'czerny'
					ELSE IF SUBSTRING(@String, @pos, 2) = 'CZ' AND SUBSTRING(@String, @pos-2, 4) != 'WICZ'
						begin
							SET @pri = CONCAT(@pri, 'S');
							set @sec = CONCAT(@sec, 'X');
							set @pos = @pos  + 2; -- nxt = ('S', 'X', 2)
						end
					-- e.g., 'focaccia'
					ELSE IF SUBSTRING(@String, @pos+1, 3) = 'CIA' 
						begin
							SET @pri = CONCAT(@pri, 'X');
							set @sec = CONCAT(@sec, 'X');
							set @pos = @pos  + 3; -- nxt = ('X', 3)
						end
					-- double 'C', but not IF e.g. 'McClellan'
					ELSE IF SUBSTRING(@String, @pos, 2) = 'CC' AND NOT (@pos = (@first +1) AND SUBSTRING(@String, @first, 1) = 'M') 
						begin
							-- 'bellocchio' but not 'bacchus'
							IF SUBSTRING(@String, @pos+2, 1) IN ('I', 'E', 'H') AND SUBSTRING(@String, @pos+2, 2) != 'HU' 
								begin
									-- 'accident', 'accede' 'succeed'
									IF (@pos = @first +1 AND SUBSTRING(@String, @first, 1) = 'A') OR SUBSTRING(@String, @pos-1, 5) IN ('UCCEE', 'UCCES') 
									   begin
											SET @pri = CONCAT(@pri, 'KS');
											set @sec = CONCAT(@sec, 'KS');
											set @pos = @pos  + 3; -- nxt = ('KS', 3)
										end
									-- 'bacci', 'bertucci', other italian
									ELSE
										begin
											SET @pri = CONCAT(@pri, 'X');
											SET @sec = CONCAT(@sec, 'X');
											SET @pos = @pos  + 3; -- nxt = ('X', 3)
										END
								end
							ELSE
								BEGIN
									SET @pri = CONCAT(@pri, 'K'); 
									SET @sec = CONCAT(@sec, 'K'); 
									SET @pos = @pos  + 2; -- nxt = ('K', 2)
								END
						end
					ELSE IF SUBSTRING(@String, @pos, 2) IN ('CK', 'CG', 'CQ') 
						BEGIN
							SET @pri = CONCAT(@pri, 'K');
							SET @sec = CONCAT(@sec, 'K');
							SET @pos = @pos  + 2; -- nxt = ('K', 'K', 2)
						END
					ELSE IF SUBSTRING(@String, @pos, 2) IN ('CI', 'CE', 'CY') 
						BEGIN
							-- italian vs. english
							IF SUBSTRING(@String, @pos, 3) IN ('CIO', 'CIE', 'CIA') 
								BEGIN
									SET @pri = CONCAT(@pri, 'S');
									SET @sec = CONCAT(@sec, 'X');
									SET @pos = @pos  + 2; -- nxt = ('S', 'X', 2)
								END
							ELSE
								BEGIN
									SET @pri = CONCAT(@pri, 'S');
									SET @sec = CONCAT(@sec, 'S');
									SET @pos = @pos  + 2; -- nxt = ('S', 2)
								END
						END
					ELSE
						BEGIN
							-- name sent IN 'mac caffrey', 'mac gregor
							IF SUBSTRING(@String, @pos+1, 2) IN (' C', ' Q', ' G') 
								BEGIN
									SET @pri = CONCAT(@pri, 'K');
									SET @sec = CONCAT(@sec, 'K');
									SET @pos = @pos  + 3; -- nxt = ('K', 3)
								END 
							ELSE
								IF SUBSTRING(@String, @pos+1, 1) IN ('C', 'K', 'Q') AND SUBSTRING(@String, @pos+1, 2) NOT IN ('CE', 'CI') 
									BEGIN
										SET @pri = CONCAT(@pri, 'K');
										SET @sec = CONCAT(@sec, 'K');
										SET @pos = @pos  + 2; -- nxt = ('K', 2)
									END
								ELSE --  default for 'C'
									BEGIN
										SET @pri = CONCAT(@pri, 'K');
										SET @sec = CONCAT(@sec, 'K');
										SET @pos = @pos  + 1; -- nxt = ('K', 1)
									END
						END
				END

			-- ELSEIF @ch = 'Ç' THEN --  will never get here with @String.encode('ascii', 'replace') above
				-- SET @pri = CONCAT(@pri, '5'), @sec = CONCAT(@sec, '5'), @pos = @pos  + 1; -- nxt = ('S', 1)
				
			ELSE IF @ch = 'D' 
				BEGIN
					IF SUBSTRING(@String, @pos, 2) = 'DG' 
						IF SUBSTRING(@String, @pos+2, 1) IN ('I', 'E', 'Y') -- e.g. 'edge'
							BEGIN
								SET @pri = CONCAT(@pri, 'J');
								SET @sec = CONCAT(@sec, 'J');
								SET @pos = @pos  + 3; -- nxt = ('J', 3)
							END
						ELSE
							BEGIN
								SET @pri = CONCAT(@pri, 'TK');
								SET @sec = CONCAT(@sec, 'TK'); 
								SET @pos = @pos  + 2; -- nxt = ('TK', 2)
							END
					ELSE IF SUBSTRING(@String, @pos, 2) IN ('DT', 'DD') 
						BEGIN
							SET @pri = CONCAT(@pri, 'T');
							SET @sec = CONCAT(@sec, 'T');
							SET @pos = @pos  + 2; -- nxt = ('T', 2)
						END
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'T');
							SET @sec = CONCAT(@sec, 'T');
							SET @pos = @pos  + 1; -- nxt = ('T', 1)
						END
				END
					
			ELSE IF @ch = 'F' 
				BEGIN
					IF SUBSTRING(@String, @pos+1, 1) = 'F' 
						BEGIN
							SET @pri = CONCAT(@pri, 'F');
							SET @sec = CONCAT(@sec, 'F');
							SET @pos = @pos  + 2; -- nxt = ('F', 2)
						END
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'F');
							SET @sec = CONCAT(@sec, 'F');
							SET @pos = @pos  + 1; -- nxt = ('F', 1)
						END
				END
					
			ELSE IF @ch = 'G' 
				BEGIN
					IF SUBSTRING(@String, @pos+1, 1) = 'H'
						IF (@pos > @first AND SUBSTRING(@String, @pos-1, 1) NOT IN ('A', 'E', 'I', 'O', 'U', 'Y')) OR ( @pos = @first AND SUBSTRING(@String, @pos+2, 1) != 'I') 
							BEGIN
								SET @pri = CONCAT(@pri, 'K');
								SET @sec = CONCAT(@sec, 'K');
								SET @pos = @pos  + 2; -- nxt = ('K', 2)
							END
						ELSE IF @pos = @first AND SUBSTRING(@String, @pos+2, 1) = 'I'
							BEGIN
								SET @pri = CONCAT(@pri, 'J');
								SET @sec = CONCAT(@sec, 'J');
								SET @pos = @pos  + 2; -- nxt = ('J', 2)
							END
						-- Parker's rule (with some further refinements) - e.g., 'hugh'
						ELSE IF (@pos > (@first + 1) AND SUBSTRING(@String, @pos-2, 1) IN ('B', 'H', 'D') )
										   OR (@pos > (@first + 2) AND SUBSTRING(@String, @pos-3, 1) IN ('B', 'H', 'D') )
										   OR (@pos > (@first + 3) AND SUBSTRING(@String, @pos-4, 1) IN ('B', 'H') ) 
								SET @pos = @pos + 2; -- nxt = (None, 2)
						ELSE
							--  e.g., 'laugh', 'McLaughlin', 'cough', 'gough', 'rough', 'tough'
							IF @pos > (@first + 2) AND SUBSTRING(@String, @pos-1, 1) = 'U' AND SUBSTRING(@String, @pos-3, 1) IN ('C', 'G', 'L', 'R', 'T') 
								BEGIN
									SET @pri = CONCAT(@pri, 'F');
									SET @sec = CONCAT(@sec, 'F');
									SET @pos = @pos  + 2; -- nxt = ('F', 2)
								END
							ELSE IF @pos > @first AND SUBSTRING(@String, @pos-1, 1) != 'I' 
								BEGIN
									SET @pri = CONCAT(@pri, 'K');
									SET @sec = CONCAT(@sec, 'K');
									SET @pos = @pos  + 2; -- nxt = ('K', 2)
								END
							ELSE
								SET @pos = @pos + 1;
								
					ELSE IF SUBSTRING(@String, @pos+1, 1) = 'N' 
						IF @pos = (@first +1) AND SUBSTRING(@String, @first, 1) IN ('A', 'E', 'I', 'O', 'U', 'Y') AND @is_slavo_germanic = 0 
							BEGIN
								SET @pri = CONCAT(@pri, 'KN');
								SET @sec = CONCAT(@sec, 'N');
								SET @pos = @pos  + 2; -- nxt = ('KN', 'N', 2)
							END
						ELSE
							--  not e.g. 'cagney'
							IF SUBSTRING(@String, @pos+2, 2) != 'EY' AND SUBSTRING(@String, @pos+1, 1) != 'Y' AND @is_slavo_germanic = 0 
								BEGIN
									SET @pri = CONCAT(@pri, 'N');
									SET @sec = CONCAT(@sec, 'KN');
									SET @pos = @pos  + 2; -- nxt = ('N', 'KN', 2)
								END
							ELSE
								BEGIN
									SET @pri = CONCAT(@pri, 'KN');
									SET @sec = CONCAT(@sec, 'KN');
									SET @pos = @pos  + 2; -- nxt = ('KN', 2)
								END
								
					--  'tagliaro'
					ELSE IF SUBSTRING(@String, @pos+1, 2) = 'LI' AND @is_slavo_germanic = 0
						BEGIN
							SET @pri = CONCAT(@pri, 'KL');
							SET @sec = CONCAT(@sec, 'L');
							SET @pos = @pos  + 2; -- nxt = ('KL', 'L', 2)
						END
						
					--  -ges-,-gep-,-gel-, -gie- at beginning
					ELSE IF @pos = @first AND (SUBSTRING(@String, @pos+1, 1) = 'Y' OR SUBSTRING(@String, @pos+1, 2) IN ('ES', 'EP', 'EB', 'EL', 'EY', 'IB', 'IL', 'IN', 'IE', 'EI', 'ER')) 
						BEGIN
							SET @pri = CONCAT(@pri, 'K');
							SET @sec = CONCAT(@sec, 'J');
							SET @pos = @pos  + 2; -- nxt = ('K', 'J', 2)
						END
						
					--  -ger-,  -gy-
					ELSE IF (SUBSTRING(@String, @pos+1, 2) = 'ER' OR SUBSTRING(@String, @pos+1, 1) = 'Y')
									   AND SUBSTRING(@String, @first, 6) NOT IN ('DANGER', 'RANGER', 'MANGER')
									   AND SUBSTRING(@String, @pos-1, 1) not IN ('E', 'I') AND SUBSTRING(@String, @pos-1, 3) NOT IN ('RGY', 'OGY') 
						BEGIN
							SET @pri = CONCAT(@pri, 'K');
							SET @sec = CONCAT(@sec, 'J');
							SET @pos = @pos  + 2; -- nxt = ('K', 'J', 2)
						END
						
					--  italian e.g, 'biaggi'
					ELSE IF SUBSTRING(@String, @pos+1, 1) IN ('E', 'I', 'Y') OR SUBSTRING(@String, @pos-1, 4) IN ('AGGI', 'OGGI') 
						BEGIN
							--  obvious germanic
							IF SUBSTRING(@String, @first, 4) IN ('VON ', 'VAN ') OR SUBSTRING(@String, @first, 3) = 'SCH' OR SUBSTRING(@String, @pos+1, 2) = 'ET' 
								BEGIN
									SET @pri = CONCAT(@pri, 'K');
									SET @sec = CONCAT(@sec, 'K');
									SET @pos = @pos  + 2; -- nxt = ('K', 2)
								END
							ELSE
								--  always soft IF french ending
								IF SUBSTRING(@String, @pos+1, 4) = 'IER ' 
									BEGIN
										SET @pri = CONCAT(@pri, 'J');
										SET @sec = CONCAT(@sec, 'J');
										SET @pos = @pos  + 2; -- nxt = ('J', 2)
									END
								ELSE
									BEGIN
										SET @pri = CONCAT(@pri, 'J');
										SET @sec = CONCAT(@sec, 'K');
										SET @pos = @pos  + 2; -- nxt = ('J', 'K', 2)
									END
						END
						
					ELSE IF SUBSTRING(@String, @pos+1, 1) = 'G' 
						BEGIN
							SET @pri = CONCAT(@pri, 'K');
							SET @sec = CONCAT(@sec, 'K');
							SET @pos = @pos  + 2; -- nxt = ('K', 2)
						END
						
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'K');
							SET @sec = CONCAT(@sec, 'K');
							SET @pos = @pos  + 1; -- nxt = ('K', 1)
						END
				END
					
			ELSE IF @ch = 'H' 
				BEGIN
					--  only keep IF @first & before vowel OR btw. 2 ('A', 'E', 'I', 'O', 'U', 'Y')
					IF (@pos = @first OR SUBSTRING(@String, @pos-1, 1) IN ('A', 'E', 'I', 'O', 'U', 'Y')) AND SUBSTRING(@String, @pos+1, 1) IN ('A', 'E', 'I', 'O', 'U', 'Y') 
						BEGIN
							SET @pri = CONCAT(@pri, 'H');
							SET @sec = CONCAT(@sec, 'H');
							SET @pos = @pos  + 2; -- nxt = ('H', 2)
						END
					ELSE --  (also takes care of 'HH')
						SET @pos = @pos + 1; -- nxt = (None, 1)
				END

			ELSE IF @ch = 'J' 
				BEGIN
					--  obvious spanish, 'jose', 'san jacinto'
					IF SUBSTRING(@String, @pos, 4) = 'JOSE' OR SUBSTRING(@String, @first, 4) = 'SAN ' 
						BEGIN
							IF (@pos = @first AND SUBSTRING(@String, @pos+4, 1) = ' ') OR SUBSTRING(@String, @first, 4) = 'SAN ' 
								BEGIN
									SET @pri = CONCAT(@pri, 'H');
									SET @sec = CONCAT(@sec, 'H'); -- nxt = ('H',)
								END
							ELSE
								BEGIN
									SET @pri = CONCAT(@pri, 'J');
									SET @sec = CONCAT(@sec, 'H'); -- nxt = ('J', 'H')
								END
						END
						
					ELSE IF @pos = @first AND SUBSTRING(@String, @pos, 4) != 'JOSE' 
						BEGIN
							SET @pri = CONCAT(@pri, 'J');
							SET @sec = CONCAT(@sec, 'A'); -- nxt = ('J', 'A') --  Yankelovich/Jankelowicz
						END
						
					ELSE
						--  spanish pron. of e.g. 'bajador'
						IF SUBSTRING(@String, @pos-1, 1) IN ('A', 'E', 'I', 'O', 'U', 'Y') AND @is_slavo_germanic = 0 AND SUBSTRING(@String, @pos+1, 1) IN ('A', 'O') 
							BEGIN
								SET @pri = CONCAT(@pri, 'J');
								SET @sec = CONCAT(@sec, 'H'); -- nxt = ('J', 'H')
							END
						ELSE
							IF @pos = @last 
								SET @pri = CONCAT(@pri, 'J'); -- nxt = ('J', ' ')
							ELSE
								IF SUBSTRING(@String, @pos+1, 1) not IN ('L', 'T', 'K', 'S', 'N', 'M', 'B', 'Z') AND SUBSTRING(@String, @pos-1, 1) not IN ('S', 'K', 'L') 
									BEGIN
										SET @pri = CONCAT(@pri, 'J');
										SET @sec = CONCAT(@sec, 'J'); -- nxt = ('J',)
									END
									
					-- next check
					IF SUBSTRING(@String, @pos+1, 1) = 'J' 
						SET @pos = @pos + 2;
					ELSE
						SET @pos = @pos + 1;
				END
				
			ELSE IF @ch = 'K' 
				BEGIN
					IF SUBSTRING(@String, @pos+1, 1) = 'K' 
						BEGIN
							SET @pri = CONCAT(@pri, 'K');
							SET @sec = CONCAT(@sec, 'K');
							SET @pos = @pos  + 2; -- nxt = ('K', 2)
						END
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'K');
							SET @sec = CONCAT(@sec, 'K');
							SET @pos = @pos  + 1; -- nxt = ('K', 1)
						END
				END
				
			ELSE IF @ch = 'L' 
				BEGIN
					IF SUBSTRING(@String, @pos+1, 1) = 'L' 
						--  spanish e.g. 'cabrillo', 'gallegos'
						IF (@pos = (@last - 2) AND SUBSTRING(@String, @pos-1, 4) IN ('ILLO', 'ILLA', 'ALLE'))
								OR ((SUBSTRING(@String, @last-1, 2) IN ('AS', 'OS') OR SUBSTRING(@String, @last, 1) IN ('A', 'O')) AND SUBSTRING(@String, @pos-1, 4) = 'ALLE')
							BEGIN
								SET @pri = CONCAT(@pri, 'L');
								SET @pos = @pos  + 2; -- nxt = ('L', ' ', 2)
							END
						ELSE
							BEGIN
								SET @pri = CONCAT(@pri, 'L');
								SET @sec = CONCAT(@sec, 'L');
								SET @pos = @pos  + 2; -- nxt = ('L', 2)
							END
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'L');
							SET @sec = CONCAT(@sec, 'L');
							SET @pos = @pos  + 1; -- nxt = ('L', 1)
						END
				END
					
			ELSE IF @ch = 'M' 
				BEGIN
					IF SUBSTRING(@String, @pos-1, 3) = 'UMB' AND (@pos + 1 = @last OR SUBSTRING(@String, @pos+2, 2) = 'ER') OR SUBSTRING(@String, @pos+1, 1) = 'M' 
						BEGIN
							SET @pri = CONCAT(@pri, 'M');
							SET @sec = CONCAT(@sec, 'M');
							SET @pos = @pos  + 2; -- nxt = ('M', 2)
						END
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'M');
							SET @sec = CONCAT(@sec, 'M');
							SET @pos = @pos  + 1; -- nxt = ('M', 1)
						END
				END
					
			ELSE IF @ch = 'N' 
				BEGIN
					IF SUBSTRING(@String, @pos+1, 1) = 'N' 
						BEGIN
							SET @pri = CONCAT(@pri, 'N');
							SET @sec = CONCAT(@sec, 'N');
							SET @pos = @pos  + 2; -- nxt = ('N', 2)
						END
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'N');
							SET @sec = CONCAT(@sec, 'N');
							SET @pos = @pos  + 1; -- nxt = ('N', 1)
						END
						
					-- ELSEIF @ch = u'Ñ' THEN
						-- SET @pri = CONCAT(@pri, '5');
						-- SET @sec = CONCAT(@sec, '5');
						-- SET @pos = @pos  + 1; -- nxt = ('N', 1)
				END

			ELSE IF @ch = 'P' 
				BEGIN
					IF SUBSTRING(@String, @pos+1, 1) = 'H' 
						BEGIN
							SET @pri = CONCAT(@pri, 'F');
							SET @sec = CONCAT(@sec, 'F');
							SET @pos = @pos  + 2; -- nxt = ('F', 2)
						END
					ELSE IF SUBSTRING(@String, @pos+1, 1) IN ('P', 'B') --  also account for 'campbell', 'raspberry'
						BEGIN
							SET @pri = CONCAT(@pri, 'P');
							SET @sec = CONCAT(@sec, 'P');
							SET @pos = @pos  + 2; -- nxt = ('P', 2)
						END
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'P');
							SET @sec = CONCAT(@sec, 'P');
							SET @pos = @pos  + 1; -- nxt = ('P', 1)
						END
				END
					
			ELSE IF @ch = 'Q' 
				BEGIN
					IF SUBSTRING(@String, @pos+1, 1) = 'Q' 
						BEGIN
							SET @pri = CONCAT(@pri, 'K');
							SET @sec = CONCAT(@sec, 'K');
							SET @pos = @pos  + 2; -- nxt = ('K', 2)
						END
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'K');
							SET @sec = CONCAT(@sec, 'K');
							SET @pos = @pos  + 1; -- nxt = ('K', 1)
						END
				END
					
			ELSE IF @ch = 'R' 
				BEGIN
					--  french e.g. 'rogier', but exclude 'hochmeier'
					IF @pos = @last AND @is_slavo_germanic = 0 AND SUBSTRING(@String, @pos-2, 2) = 'IE' AND SUBSTRING(@String, @pos-4, 2) NOT IN ('ME', 'MA') 
						SET @sec = CONCAT(@sec, 'R'); -- nxt = ('', 'R')
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'R');
							SET @sec = CONCAT(@sec, 'R'); -- nxt = ('R',)
						END
						
					IF SUBSTRING(@String, @pos+1, 1) = 'R'
						SET @pos = @pos + 2;
					ELSE
						SET @pos = @pos + 1;
				END
				
			ELSE IF @ch = 'S' 
				BEGIN
					--  special cases 'island', 'isle', 'carlisle', 'carlysle'
					IF SUBSTRING(@String, @pos-1, 3) IN ('ISL', 'YSL') 
						SET @pos = @pos + 1;
						
					--  special case 'sugar-'
					ELSE IF @pos = @first AND SUBSTRING(@String, @first, 5) = 'SUGAR'
						BEGIN
							SET @pri = CONCAT(@pri, 'X');
							SET @sec = CONCAT(@sec, 'S');
							SET @pos = @pos  + 1; --  nxt =('X', 'S', 1)
						END 
						
					ELSE IF SUBSTRING(@String, @pos, 2) = 'SH' 
						--  germanic
						IF SUBSTRING(@String, @pos+1, 4) IN ('HEIM', 'HOEK', 'HOLM', 'HOLZ') 
							BEGIN
								SET @pri = CONCAT(@pri, 'S');
								SET @sec = CONCAT(@sec, 'S');
								SET @pos = @pos  + 2; -- nxt = ('S', 2)
							END
						ELSE
							BEGIN
								SET @pri = CONCAT(@pri, 'X');
								SET @sec = CONCAT(@sec, 'X');
								SET @pos = @pos  + 2; -- nxt = ('X', 2)
							END
						
					--  italian & armenian
					ELSE IF SUBSTRING(@String, @pos, 3) IN ('SIO', 'SIA') OR SUBSTRING(@String, @pos, 4) = 'SIAN'
						IF @is_slavo_germanic = 0 
							BEGIN
								SET @pri = CONCAT(@pri, 'S');
								SET @sec = CONCAT(@sec, 'X');
								SET @pos = @pos  + 3; -- nxt = ('S', 'X', 3)
							END
						ELSE
							BEGIN
								SET @pri = CONCAT(@pri, 'S');
								SET @sec = CONCAT(@sec, 'S');
								SET @pos = @pos  + 3; -- nxt = ('S', 3)
							END
						
					--  german & anglicisations, e.g. 'smith' match 'schmidt', 'snider' match 'schneider'
					--  also, -sz- IN slavic language altho IN hungarian it is pronounced 's'
					ELSE IF (@pos = @first AND SUBSTRING(@String, @pos+1, 1) IN ('M', 'N', 'L', 'W')) OR SUBSTRING(@String, @pos+1, 1) = 'Z' 
						BEGIN
							SET @pri = CONCAT(@pri, 'S');
							SET @sec = CONCAT(@sec, 'X'); -- nxt = ('S', 'X')
							
							IF SUBSTRING(@String, @pos+1, 1) = 'Z'
								SET @pos = @pos + 2;
							ELSE
								SET @pos = @pos + 1;
						END

					ELSE IF SUBSTRING(@String, @pos, 2) = 'SC'
						BEGIN
							--  Schlesinger's rule
							IF SUBSTRING(@String, @pos+2, 1) = 'H' 
								BEGIN
									--  dutch origin, e.g. 'school', 'schooner'
									IF SUBSTRING(@String, @pos+3, 2) IN ('OO', 'ER', 'EN', 'UY', 'ED', 'EM') 
										--  'schermerhorn', 'schenker'
										IF SUBSTRING(@String, @pos+3, 2) IN ('ER', 'EN') 
											BEGIN
												SET @pri = CONCAT(@pri, 'X');
												SET @sec = CONCAT(@sec, 'SK');
												SET @pos = @pos  + 3; -- nxt = ('X', 'SK', 3)
											END
										ELSE
											BEGIN
												SET @pri = CONCAT(@pri, 'SK');
												SET @sec = CONCAT(@sec, 'SK');
												SET @pos = @pos  + 3; -- nxt = ('SK', 3)
											END
									ELSE
										IF @pos = @first AND SUBSTRING(@String, @first+3, 1) not IN ('A', 'E', 'I', 'O', 'U', 'Y') AND SUBSTRING(@String, @first+3, 1) != 'W' 
											BEGIN
												SET @pri = CONCAT(@pri, 'X');
												SET @sec = CONCAT(@sec, 'S');
												SET @pos = @pos  + 3; -- nxt = ('X', 'S', 3)
											END
										ELSE
											BEGIN
												SET @pri = CONCAT(@pri, 'X');
												SET @sec = CONCAT(@sec, 'X');
												SET @pos = @pos  + 3; -- nxt = ('X', 3)
											END
								END
								
							ELSE IF SUBSTRING(@String, @pos+2, 1) IN ('I', 'E', 'Y')
								BEGIN
									SET @pri = CONCAT(@pri, 'S');
									SET @sec = CONCAT(@sec, 'S');
									SET @pos = @pos  + 3; -- nxt = ('S', 3)
								END
								
							ELSE
								BEGIN
									SET @pri = CONCAT(@pri, 'SK');
									SET @sec = CONCAT(@sec, 'SK');
									SET @pos = @pos  + 3; -- nxt = ('SK', 3)
								END
						END
						
					--  french e.g. 'resnais', 'artois'
					ELSE IF @pos = @last AND SUBSTRING(@String, @pos-2, 2) IN ('AI', 'OI') 
						BEGIN
							SET @sec = CONCAT(@sec, 'S');
							SET @pos = @pos  + 1; -- nxt = ('', 'S')
						END
						
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'S');
							SET @sec = CONCAT(@sec, 'S'); -- nxt = ('S',)
							
							IF SUBSTRING(@String, @pos+1, 1) IN ('S', 'Z')
								SET @pos = @pos + 2;
							ELSE
								SET @pos = @pos + 1;
						END
				END

			ELSE IF @ch = 'T' 
				BEGIN
					IF SUBSTRING(@String, @pos, 4) = 'TION' 
						BEGIN
							SET @pri = CONCAT(@pri, 'X');
							SET @sec = CONCAT(@sec, 'X');
							SET @pos = @pos  + 3; -- nxt = ('X', 3)
						END
						
					ELSE IF SUBSTRING(@String, @pos, 3) IN ('TIA', 'TCH') 
						BEGIN
							SET @pri = CONCAT(@pri, 'X');
							SET @sec = CONCAT(@sec, 'X');
							SET @pos = @pos  + 3; -- nxt = ('X', 3)
						END
						
					ELSE IF SUBSTRING(@String, @pos, 2) = 'TH' OR SUBSTRING(@String, @pos, 3) = 'TTH' 
						BEGIN
							--  special case 'thomas', 'thames' OR germanic
							IF SUBSTRING(@String, @pos+2, 2) IN ('OM', 'AM') OR SUBSTRING(@String, @first, 4) IN ('VON ', 'VAN ') OR SUBSTRING(@String, @first, 3) = 'SCH' 
								BEGIN
									SET @pri = CONCAT(@pri, 'T');
									SET @sec = CONCAT(@sec, 'T');
									SET @pos = @pos  + 2; -- nxt = ('T', 2)
								END
							ELSE
								BEGIN
									SET @pri = CONCAT(@pri, '0');
									SET @sec = CONCAT(@sec, 'T');
									SET @pos = @pos  + 2; -- nxt = ('0', 'T', 2)
								END
						END
						
					ELSE IF SUBSTRING(@String, @pos+1, 1) IN ('T', 'D') 
						BEGIN
							SET @pri = CONCAT(@pri, 'T');
							SET @sec = CONCAT(@sec, 'T');
							SET @pos = @pos  + 2; -- nxt = ('T', 2)
						END
						
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'T');
							SET @sec = CONCAT(@sec, 'T');
							SET @pos = @pos  + 1; -- nxt = ('T', 1)
						END
				END
					
			ELSE IF @ch = 'V' 
				BEGIN
					IF SUBSTRING(@String, @pos+1, 1) = 'V' 
						BEGIN
							SET @pri = CONCAT(@pri, 'F');
							SET @sec = CONCAT(@sec, 'F');
							SET @pos = @pos  + 2; -- nxt = ('F', 2)
						END
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'F');
							SET @sec = CONCAT(@sec, 'F');
							SET @pos = @pos  + 1; -- nxt = ('F', 1)
						END
				END
					
			ELSE IF @ch = 'W' 
				BEGIN
					--  can also be IN middle of word
					IF SUBSTRING(@String, @pos, 2) = 'WR' 
						BEGIN
							SET @pri = CONCAT(@pri, 'R');
							SET @sec = CONCAT(@sec, 'R');
							SET @pos = @pos  + 2; -- nxt = ('R', 2)
						END
						
					ELSE IF @pos = @first AND (SUBSTRING(@String, @pos+1, 1) IN ('A', 'E', 'I', 'O', 'U', 'Y') OR SUBSTRING(@String, @pos, 2) = 'WH') 
						--  Wasserman should match Vasserman
						IF SUBSTRING(@String, @pos+1, 1) IN ('A', 'E', 'I', 'O', 'U', 'Y') 
							BEGIN
								SET @pri = CONCAT(@pri, 'A');
								SET @sec = CONCAT(@sec, 'F');
								SET @pos = @pos  + 1; -- nxt = ('A', 'F', 1)
							END
						ELSE IF SUBSTRING(@String, @pos, 3) = 'WHO'
							BEGIN
								SET @pri = CONCAT(@pri, 'H');
								SET @sec = CONCAT(@sec, 'H');
								SET @pos = @pos  + 1; -- nxt = ('H', 1)
							END
						ELSE
							BEGIN
								SET @pri = CONCAT(@pri, 'A');
								SET @sec = CONCAT(@sec, 'A');
								SET @pos = @pos  + 1; -- nxt = ('A', 1)
							END
							
					--  Arnow should match Arnoff
					ELSE IF (@pos = @last AND SUBSTRING(@String, @pos-1, 1) IN ('A', 'E', 'I', 'O', 'U', 'Y'))
								OR SUBSTRING(@String, @pos-1, 5) IN ('EWSKI', 'EWSKY', 'OWSKI', 'OWSKY')
								OR SUBSTRING(@String, @first, 3) = 'SCH' 
						BEGIN
							SET @sec = CONCAT(@sec, 'F');
							SET @pos = @pos  + 1; -- nxt = ('', 'F', 1)
						END

					-- END IF;
					--  polish e.g. 'filipowicz'
					ELSE IF SUBSTRING(@String, @pos, 4) IN ('WICZ', 'WITZ') 
						BEGIN
							SET @pri = CONCAT(@pri, 'TS');
							SET @sec = CONCAT(@sec, 'FX');
							SET @pos = @pos  + 4; -- nxt = ('TS', 'FX', 4)
						END
						
					ELSE --  default is to skip it
						SET @pos = @pos + 1;
				END
					
			ELSE IF @ch = 'X' 
				BEGIN
					--  french e.g. breaux
					IF not(@pos = @last AND (SUBSTRING(@String, @pos-3, 3) IN ('IAU', 'EAU') OR SUBSTRING(@String, @pos-2, 2) IN ('AU', 'OU'))) 
						BEGIN
							SET @pri = CONCAT(@pri, 'KS');
							SET @sec = CONCAT(@sec, 'KS'); -- nxt = ('KS',)
						END
						
					IF SUBSTRING(@String, @pos+1, 1) IN ('C', 'X') 
						SET @pos = @pos + 2;
					ELSE
						SET @pos = @pos + 1;
				END
				
			ELSE IF @ch = 'Z' 
				BEGIN
					--  chinese pinyin e.g. 'zhao'
					IF SUBSTRING(@String, @pos+1, 1) = 'H' 
						BEGIN
							SET @pri = CONCAT(@pri, 'J');
							SET @sec = CONCAT(@sec, 'J');
							SET @pos = @pos  + 1; -- nxt = ('J', 2)
						END
					
					ELSE IF SUBSTRING(@String, @pos+1, 3) IN ('ZO', 'ZI', 'ZA') OR (@is_slavo_germanic = 1 AND @pos > @first AND SUBSTRING(@String, @pos-1, 1) != 'T') 
						BEGIN
							SET @pri = CONCAT(@pri, 'S');
							SET @sec = CONCAT(@sec, 'TS'); -- nxt = ('S', 'TS')
						END
						
					ELSE
						BEGIN
							SET @pri = CONCAT(@pri, 'S');
							SET @sec = CONCAT(@sec, 'S'); -- nxt = ('S',)
						END
						
					IF SUBSTRING(@String, @pos+1, 1) = 'Z' 
						SET @pos = @pos + 2;
					ELSE
						SET @pos = @pos + 1;
				END
				
			ELSE
				SET @pos = @pos + 1; -- DEFAULT is to move to next char
			
			IF @pos = @prevpos 
				begin
					SET @pos = @pos +1;
					SET @pri = CONCAT(@pri,'<didnt incr>'); -- it might be better to throw an error here if you really must be accurate
				END
	
		END -- END WHILE main loop;
	
	IF @pri != @sec 
		SET @retStr = CONCAT(@pri, ';', @sec);
	ELSE 
		SET @retStr = @pri;
  
	RETURN (@retStr);
END

GO
