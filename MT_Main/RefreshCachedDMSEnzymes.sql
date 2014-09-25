/****** Object:  StoredProcedure [dbo].[RefreshCachedDMSEnzymes] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE RefreshCachedDMSEnzymes
/****************************************************
**
**	Desc:	Updates the data in T_DMS_Enzymes_Cached using DMS
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	08/02/2010 mem - Initial Version
**			09/23/2014 mem - Now treating error 53 as a warning (Named Pipes Provider: Could not open a connection to SQL Server)
**
*****************************************************/
(
	@message varchar(255) = '' output
)
AS

	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	set @message = ''

	Declare @DeleteCount int
	Declare @UpdateCount int
	Declare @InsertCount int

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	---------------------------------------------------
	-- Create the temporary table that will be used to
	-- track the number of inserts, updates, and deletes 
	-- performed by the MERGE statement
	---------------------------------------------------
	
	CREATE TABLE #Tmp_UpdateSummary (
		UpdateAction varchar(32)
	)
		
	Begin Try

		Set @CurrentLocation = 'Update Last_Refreshed in T_DMS_Cached_Data_Status'
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Enzymes_Cached', @IncrementRefreshCount = 0, @FullRefreshPerformed = 1, @LastRefreshMinimumID = 0

		Set @CurrentLocation = 'Merge data into T_DMS_Enzymes_Cached'

		-- Use a MERGE Statement to synchronize T_DMS_Enzymes_Cached with V_DMS_Enzymes_Import	
		--
		MERGE T_DMS_Enzymes_Cached AS target
		USING (	SELECT Enzyme_ID, Enzyme_Name,
                       Description, Protein_Collection_Name
				FROM V_DMS_Enzymes_Import
			) AS Source ( Enzyme_ID, Enzyme_Name,
                          Description, Protein_Collection_Name)
		ON (target.Enzyme_ID = source.Enzyme_ID)
		WHEN Matched AND (target.Enzyme_Name <> source.Enzyme_Name OR
                          target.Description <> source.Description OR
					      IsNull(target.Protein_Collection_Name, '') <> IsNull(source.Protein_Collection_Name, '')
						) THEN 
			UPDATE set Enzyme_Name = source.Enzyme_Name,
                       Description = source.Description, 
                       Protein_Collection_Name = source.Protein_Collection_Name,
					   Last_Affected = GetDate()
		WHEN Not Matched THEN
			INSERT ( Enzyme_ID, Enzyme_Name,
                     Description, Protein_Collection_Name, Last_Affected)
			VALUES (source.Enzyme_ID, 
					source.Enzyme_Name,
                    source.Description, 
                    source.Protein_Collection_Name,
					GetDate())
		WHEN NOT MATCHED BY SOURCE THEN 
			DELETE
		OUTPUT $action INTO #Tmp_UpdateSummary
		;
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		if @myError <> 0
		begin
			set @message = 'Error merging V_DMS_Enzymes_Import with T_DMS_Enzymes_Cached (ErrorID = ' + Convert(varchar(12), @myError) + ')'
			execute PostLogEntry 'Error', @message, 'RefreshCachedDMSEnzymes'
		end

		-- Update the stats in T_DMS_Cached_Data_Status
		exec RefreshCachedDMSInfoFinalize 'RefreshCachedDMSEnzymes', '', 'T_DMS_Enzymes_Cached'
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedDMSEnzymes')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList=53,
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch
				
Done:

	drop table #Tmp_UpdateSummary
	
	Return @myError

GO
