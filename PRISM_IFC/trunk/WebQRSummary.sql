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
**  Auth: jee
**	Date:	 04/16/2004
**			 10/22/2004 mem - Added PostUsageLogEntry
**			 04/05/2005 mem - Added parameter @VerboseColumnOutput
**			 11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**
****************************************************/
(
	@MTDBName varchar(128) = '',
	@QuantitationIDList varchar(1024),			-- Comma separated list of Quantitation ID's
	@message varchar(512) = '' output,
	@VerboseColumnOutput tinyint = 0			-- Set to 1 to include all of the output columns; 0 to hide the less commonly used columns (at present, this parameter is unused, but is included for symmetry with WebQRRetrievePeptidesMultiQID)
)
AS
	SET NOCOUNT ON
	
	declare @result int
	declare @stmt nvarchar(100)
	declare @params nvarchar(100)
	set @stmt = N'exec [' + @MTDBName + N'].dbo.QRSummary @QuantitationIDList, @VerboseColumnOutput'
	set @params = N'@QuantitationIDList varchar(1024), @VerboseColumnOutput tinyint'
	exec @result = sp_executesql @stmt, @params, @QuantitationIDList = @QuantitationIDList, @VerboseColumnOutput = @VerboseColumnOutput
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = @QuantitationIDList
	Exec PostUsageLogEntry 'WebQRSummary', @MTDBName, @UsageMessage

	set @message = ''
	RETURN @result

GO
GRANT EXECUTE ON [dbo].[WebQRSummary] TO [DMS_SP_User]
GO
