/****** Object:  StoredProcedure [dbo].[WebQRSummary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.WebQRSummary
/****************************************************	
**  Desc: Returns a summary for task or tasks listed
**        in @QuantitationIDList
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: Mass Tag DB name and QuantitationID List to process
**
**  Auth: 	jee
**	Date:	04/16/2004
**			10/22/2004 mem - Added PostUsageLogEntry
**			04/05/2005 mem - Added parameter @VerboseColumnOutput
**			11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**			11/28/2006 mem - Added parameter @SortMode, which affects the order in which the results are returned
**			05/22/2007 mem - Expanded the size of @stmt and @params to nvarchar(1024)
**			06/13/2007 mem - Expanded the size of @QuantitationIDList to varchar(4000)
**
****************************************************/
(
	@MTDBName varchar(128) = '',
	@QuantitationIDList varchar(4000),			-- Comma separated list of Quantitation ID's
	@message varchar(512) = '' output,
	@VerboseColumnOutput tinyint = 0,			-- Set to 1 to include all of the output columns; 0 to hide the less commonly used columns (at present, this parameter is unused, but is included for symmetry with WebQRRetrievePeptidesMultiQID)
	@SortMode tinyint=2							-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job)
)
AS
	SET NOCOUNT ON
	
	declare @result int
	declare @stmt nvarchar(1024)
	declare @params nvarchar(1024
	)
	set @stmt = N'exec [' + @MTDBName + N'].dbo.QRSummary @QuantitationIDList, @VerboseColumnOutput, @SortMode'
	set @params = N'@QuantitationIDList varchar(max), @VerboseColumnOutput tinyint, @SortMode tinyint'
	exec @result = sp_executesql @stmt, @params, @QuantitationIDList = @QuantitationIDList, @VerboseColumnOutput = @VerboseColumnOutput, @SortMode = @SortMode
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = @QuantitationIDList
	Exec PostUsageLogEntry 'WebQRSummary', @MTDBName, @UsageMessage

	set @message = ''
	RETURN @result


GO
GRANT EXECUTE ON [dbo].[WebQRSummary] TO [DMS_SP_User]
GO
