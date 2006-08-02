SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[WebQRRetrieveProteinsMultiQID]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[WebQRRetrieveProteinsMultiQID]
GO

CREATE PROCEDURE dbo.WebQRRetrieveProteinsMultiQID
/****************************************************	
**  Desc: Calls QRRetrieveProteinsMultiQID in the specified mass tag database
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: Mass Tag DB name, QID list, and SeparateReplicateDataIDs option
**
**  Auth: jee
**	Date: 4/15/2004
**
**	Updated: 05/06/2004 mem - Added @SeparateReplicateDataIDs parameter
**			 05/07/2004 mem - Increased variable size for @stmt from nvarchar(100) to nvarchar(512)
**			 10/22/2004 mem - Added PostUsageLogEntry
**			 11/19/2004 mem - Added @ReplicateCountAvgMinimum and @Description parameters
**			 04/05/2005 mem - Added parameter @VerboseColumnOutput
**			 11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**
****************************************************/
(
	@MTDBName varchar(128) = '',
	@QuantitationIDList varchar(1024),			-- Comma separated list of Quantitation ID's
	@SeparateReplicateDataIDs tinyint = 0,		-- Set to 1 to separate replicate-based QID's
	@message varchar(512) = '' output,
	@ReplicateCountAvgMinimum decimal(9,5)=1,
	@Description varchar(32) = '' output,
	@VerboseColumnOutput tinyint = 0			-- Set to 1 to include all of the output columns; 0 to hide the less commonly used columns (at present, this parameter is unused, but is included for symmetry with WebQRRetrievePeptidesMultiQID)
)
AS
	SET NOCOUNT ON
	
	declare @result int
	declare @stmt nvarchar(512)
	declare @params nvarchar(256)
	set @stmt = N'exec [' + @MTDBName + N'].dbo.QRRetrieveProteinsMultiQID @QuantitationIDList, @SeparateReplicateDataIDs, @ReplicateCountAvgMinimum, @Description OUTPUT, @VerboseColumnOutput'
	set @params = N'@QuantitationIDList varchar(1024), @SeparateReplicateDataIDs tinyint, @ReplicateCountAvgMinimum decimal(9,5), @Description varchar(32) OUTPUT, @VerboseColumnOutput tinyint'
	exec @result = sp_executesql @stmt, @params, @QuantitationIDList = @QuantitationIDList, @SeparateReplicateDataIDs = @SeparateReplicateDataIDs, @ReplicateCountAvgMinimum = @ReplicateCountAvgMinimum, @Description = @Description OUTPUT, @VerboseColumnOutput = @VerboseColumnOutput
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = @QuantitationIDList
	Exec PostUsageLogEntry 'WebQRRetrieveProteinsMultiQID', @MTDBName, @UsageMessage

	set @message = ''
	RETURN @result

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[WebQRRetrieveProteinsMultiQID]  TO [DMS_SP_User]
GO

