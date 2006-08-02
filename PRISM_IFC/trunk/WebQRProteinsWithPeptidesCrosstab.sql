SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[WebQRProteinsWithPeptidesCrosstab]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[WebQRProteinsWithPeptidesCrosstab]
GO

CREATE PROCEDURE dbo.WebQRProteinsWithPeptidesCrosstab
/****************************************************	
**  Desc: Calls QRProteinsWithPeptidesCrosstab in the specified mass tag database
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: Mass Tag DB name, Source column name, and QID list
**
**  Auth: jee
**	Date:	 04/15/2004
**			 10/22/2004 mem - Added PostUsageLogEntry
**			 11/19/2004 mem - Added three parameters: @SeparateReplicateDataIDs, @AggregateColName, and @AverageAcrossColumns
**			 11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**
****************************************************/
(
	@MTDBName varchar(128) = '',
	@SourceColName varchar(128) = 'MT_Abundance',	-- Column to return
	@QuantitationIDList varchar(1024),				-- Comma separated list of Quantitation ID's
	@message varchar(512) = '' output,
	@SeparateReplicateDataIDs tinyint=1,
	@AggregateColName varchar(128) = '',
	@AverageAcrossColumns tinyint=1
)
AS
	SET NOCOUNT ON
	
	declare @result int
	declare @stmt nvarchar(300)
	declare @params nvarchar(300)
	
	If Len(IsNull(@AggregateColName, '')) = 0
		set @AggregateColName = @SourceColName + '_Avg'

	set @stmt = N'exec [' + @MTDBName + N'].dbo.QRProteinsWithPeptidesCrosstab @QuantitationIDList, @SeparateReplicateDataIDs, @SourceColName, @AggregateColName, @AverageAcrossColumns'
	set @params = N'@QuantitationIDList varchar(1024),@SeparateReplicateDataIDs tinyint,@SourceColName varchar(128),@AggregateColName varchar(128),@AverageAcrossColumns tinyint'
	exec @result = sp_executesql @stmt, @params, @QuantitationIDList = @QuantitationIDList, @SeparateReplicateDataIDs = @SeparateReplicateDataIDs, @SourceColName = @SourceColName, @AggregateColName = @AggregateColName, @AverageAcrossColumns = @AverageAcrossColumns
	--
	Declare @UsageMessage varchar(512)
	Set @UsageMessage = @QuantitationIDList + '; ' + @SourceColName
	Exec PostUsageLogEntry 'WebQRProteinsWithPeptidesCrosstab', @MTDBName, @UsageMessage

	set @message = ''
	RETURN @result

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[WebQRProteinsWithPeptidesCrosstab]  TO [DMS_SP_User]
GO

