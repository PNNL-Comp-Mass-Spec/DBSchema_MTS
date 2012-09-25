/****** Object:  StoredProcedure [dbo].[RefreshCachedOrganismDBInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RefreshCachedOrganismDBInfo
/****************************************************
**
**	Desc:	Updates the data in T_DMS_Organism_DB_Info
**			using V_Organism_DB_File_Export
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	12/14/2010 mem - Initial version
**			08/01/2012 mem - Now using Cached_RowVersion and OrgFile_RowVersion to determine new/changed protein collection entries
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
	Set @DeleteCount = 0
	Set @UpdateCount = 0
	Set @InsertCount = 0

	Declare @S varchar(max)

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
		Exec UpdateDMSCachedDataStatus 'T_DMS_Organism_DB_Info', @IncrementRefreshCount = 0, @FullRefreshPerformed = 1, @LastRefreshMinimumID = 0

		Set @CurrentLocation = 'Merge data into T_DMS_Organism_DB_Info'

		-- Use a MERGE Statement to synchronize T_DMS_Organism_DB_Info with V_Protein_Collection_List_Export
		--
		
		 MERGE T_DMS_Organism_DB_Info AS target
		 USING (SELECT ID, FileName, Organism, Description, Active, 
		               NumProteins, NumResidues, Organism_ID, OrgFile_RowVersion
                FROM V_DMS_Organism_DB_File_Import
			) AS Source ( ID, FileName, Organism, Description, Active, 
		                  NumProteins, NumResidues, Organism_ID, OrgFile_RowVersion)
		 ON (target.ID = source.ID)
		 WHEN Matched AND ( target.Cached_RowVersion <> Source.OrgFile_RowVersion) THEN 
			UPDATE Set
					FileName = Source.FileName,
					Organism = Source.Organism,
					Description = IsNull(Source.Description, ''),
					Active = Source.Active,
					NumProteins = IsNull(Source.NumProteins, 0),
					NumResidues = IsNull(Source.NumResidues, 0),
					Organism_ID = Source.Organism_ID,
					Cached_RowVersion = Source.OrgFile_RowVersion,
					Last_Affected = GetDate()
		 WHEN Not Matched THEN
			INSERT ( ID, FileName, Organism, Description, Active, 
		             NumProteins, NumResidues, Organism_ID, Cached_RowVersion, Last_Affected)
			VALUES ( Source.ID, Source.FileName, Source.Organism, Source.Description, Source.Active, 
		             Source.NumProteins, Source.NumResidues, Source.Organism_ID, Source.OrgFile_RowVersion, GetDate())
		 WHEN NOT MATCHED BY SOURCE THEN
			DELETE
		 OUTPUT $action INTO #Tmp_UpdateSummary
		 ;
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myError <> 0
		Begin
			set @message = 'Error merging V_DMS_Organism_DB_File_Import with T_DMS_Organism_DB_Info (ErrorID = ' + Convert(varchar(12), @myError) + ')'
			execute PostLogEntry 'Error', @message, 'RefreshCachedOrganismDBInfo'
		End
		Else
		Begin

			-- Update the stats in T_DMS_Cached_Data_Status
			exec RefreshCachedDMSInfoFinalize 'RefreshCachedOrganismDBInfo', 'V_DMS_Organism_DB_File_Import', 'T_DMS_Organism_DB_Info',
												@IncrementRefreshCount = 1, 
												@FullRefreshPerformed = 1, 
												@LastRefreshMinimumID = 0
		End

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedOrganismDBInfo')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch

Done:
	Return @myError


GO
