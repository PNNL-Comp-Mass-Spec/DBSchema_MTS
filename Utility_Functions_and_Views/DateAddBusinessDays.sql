-- From http://stackoverflow.com/questions/5471524/add-business-days-to-date-in-sql-without-loops
-- Posted by http://stackoverflow.com/users/2623042/arjen
--
-- This function can add and subtract business days regardless of the value of @@DATEFIRST. 
-- To subtract business days use a negative number of days.

CREATE FUNCTION DateAddBusinessDays
(
    @Days int,
    @Date datetime  
)
RETURNS datetime
AS
BEGIN
    DECLARE @DayOfWeek int;

    SET @DayOfWeek = CASE 
                        WHEN @Days < 0 THEN (@@DateFirst + DATEPART(weekday, @Date) - 20) % 7
                        ELSE (@@DateFirst + DATEPART(weekday, @Date) - 2) % 7
                     END;

    IF @DayOfWeek = 6 SET @Days = @Days - 1
    ELSE IF @DayOfWeek = -6 SET @Days = @Days + 1;

    RETURN @Date + @Days + (@Days + @DayOfWeek) / 5 * 2;
END;