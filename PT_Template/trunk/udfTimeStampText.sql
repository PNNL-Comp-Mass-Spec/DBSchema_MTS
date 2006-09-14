/****** Object:  UserDefinedFunction [dbo].[udfTimeStampText] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create FUNCTION udfTimeStampText
/****************************************************	
**	Returns a time stamp for the value specified by @CurrentTime
**	The time stamp will be in the form: 2006-09-01 09:05:03
**
**	Auth:	mem
**	Date:	09/01/2006
**  
****************************************************/
(
	@CurrentTime datetime
)
RETURNS varchar(20)
AS
BEGIN
	Declare @DateTimeStamp varchar(20)
	Declare @MonthCode varchar(2)
	Declare @DayCode varchar(2)
	Declare @HourCode varchar(2)
	Declare @MinuteCode varchar(2)
	Declare @SecondCode varchar(2)
	
	Set @MonthCode = Convert(varchar(2), MONTH(@CurrentTime))
	If Len(@MonthCode) = 1
		Set @MonthCode = '0' + @MonthCode

	Set @DayCode = DATENAME(dd, @CurrentTime)
	If Len(@DayCode) = 1
		Set @DayCode = '0' + @DayCode

	Set @HourCode = DATENAME(hh, @CurrentTime)
	If Len(@HourCode) = 1
		Set @HourCode = '0' + @HourCode

	Set @MinuteCode = DATENAME(n, @CurrentTime)
	If Len(@MinuteCode) = 1
		Set @MinuteCode = '0' + @MinuteCode

	Set @SecondCode = DATENAME(s, @CurrentTime)
	If Len(@SecondCode) = 1
		Set @SecondCode = '0' + @SecondCode

	Set @DateTimeStamp = DATENAME(yy, @CurrentTime) + '-' + @MonthCode + '-' + @DayCode + ' ' + @HourCode + ':' + @MinuteCode + ':' + @SecondCode
		
	RETURN @DateTimeStamp 
END

GO
