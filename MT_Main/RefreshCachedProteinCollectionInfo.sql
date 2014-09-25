/****** Object:  StoredProcedure [dbo].[RefreshCachedProteinCollectionInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE RefreshCachedProteinCollectionInfo
/****************************************************
**
**	Desc:	Updates the data in T_DMS_Protein_Collection_Info and
**			T_DMS_Protein_Collection_Archived_Output_File_Stats
**			using the Protein_Sequences database views
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	12/13/2010 mem - Initial version
**			08/01/2012 mem - Now using Cached_RowVersion and Collection_RowVersion to determine new/changed protein collection entries
**			08/02/2012 mem - Turned ANSI_WARNINGS back on since we were getting error "Heterogeneous queries require the ANSI_NULLS and ANSI_WARNINGS options to be set for the connection"
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
		Exec UpdateDMSCachedDataStatus 'T_DMS_Protein_Collection_Info', @IncrementRefreshCount = 0, @FullRefreshPerformed = 1, @LastRefreshMinimumID = 0

		Set @CurrentLocation = 'Merge data into T_DMS_Protein_Collection_Info'

		-- Use a MERGE Statement to synchronize T_DMS_Protein_Collection_Info with V_Protein_Collection_List_Export
		MERGE T_DMS_Protein_Collection_Info AS target
		USING (SELECT PCL.Protein_Collection_ID, PCL.Name, PCL.Description,
                       PCL.Collection_State, PCL.Collection_Type,
		               PCL.Protein_Count, PCL.Residue_Count,
		               PCL.Annotation_Naming_Authority, PCL.Annotation_Type,
		               MIN(PCL.Organism_ID) AS Organism_ID_First,
		               MAX(PCL.Organism_ID) AS Organism_ID_Last,
		               PCL.Created, PCL.Last_Modified, PCL.Authentication_Hash,
		               PCL.Collection_RowVersion
		       FROM V_DMS_Protein_Collection_List_Import PCL
		       GROUP BY PCL.Protein_Collection_ID, PCL.Name, PCL.Description,
		              PCL.Collection_State, PCL.Collection_Type,
		              PCL.Protein_Count, PCL.Residue_Count,
		              PCL.Annotation_Naming_Authority, PCL.Annotation_Type,
		              PCL.Created, PCL.Last_Modified, PCL.Authentication_Hash, 
		              PCL.Collection_RowVersion
			) AS Source (	Protein_Collection_ID, Name, Description,
		                    Collection_State, Collection_Type,
		                    Protein_Count, Residue_Count,
		                    Annotation_Naming_Authority, Annotation_Type,
		                    Organism_ID_First, Organism_ID_Last,
		                    Created, Last_Modified, Authentication_Hash, 
		                    Collection_RowVersion)
		ON (target.Protein_Collection_ID = source.Protein_Collection_ID)
		WHEN Matched AND (  Target.Cached_RowVersion <> Source.Collection_RowVersion ) THEN 
			UPDATE Set
		          Name = Source.Name,
		          Description = Source.Description,
		          Collection_State = Source.Collection_State,
		      Collection_Type = Source.Collection_Type,
		          Protein_Count = IsNull(Source.Protein_Count, 0),
		          Residue_Count = IsNull(Source.Residue_Count, 0),
		          Annotation_Naming_Authority = Source.Annotation_Naming_Authority,
		          Annotation_Type = Source.Annotation_Type,
		          Organism_ID_First = IsNull(Source.Organism_ID_First, 0),
		          Organism_ID_Last = IsNull(Source.Organism_ID_Last, 0),
		          Created = IsNull(Source.Created, '1/1/1980'),
		          Last_Modified = IsNull(Source.Last_Modified, '1/1/1980'),
		          Authentication_Hash = Source.Authentication_Hash,
		          Cached_RowVersion = Source.Collection_RowVersion,
		          Last_Affected = GetDate()
		WHEN Not Matched THEN
			INSERT ( Protein_Collection_ID, Name, Description, Collection_State, 
		             Collection_Type, Protein_Count, Residue_Count, 
		             Annotation_Naming_Authority, Annotation_Type, Organism_ID_First, 
		             Organism_ID_Last, Created, Last_Modified, Authentication_Hash, Cached_RowVersion, Last_Affected)
			VALUES ( Source.Protein_Collection_ID, Source.Name, Source.Description, Source.Collection_State,
		             Source.Collection_Type, Source.Protein_Count, Source.Residue_Count,
		             Source.Annotation_Naming_Authority, Source.Annotation_Type, Source.Organism_ID_First,
		             Source.Organism_ID_Last, Source.Created, Source.Last_Modified, Source.Authentication_Hash, Source.Collection_RowVersion, GetDate())
		WHEN NOT MATCHED BY SOURCE THEN
			DELETE
		OUTPUT $action INTO #Tmp_UpdateSummary
		;
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myError <> 0
		Begin
			set @message = 'Error merging V_Protein_Collection_List_Import with T_DMS_Protein_Collection_Info (ErrorID = ' + Convert(varchar(12), @myError) + ')'
			execute PostLogEntry 'Error', @message, 'RefreshCachedProteinCollectionInfo'
		End
		Else
		Begin

			-- Update the stats in T_DMS_Cached_Data_Status
			exec RefreshCachedDMSInfoFinalize 'RefreshCachedProteinCollectionInfo', 'V_Protein_Collection_List_Import', 'T_DMS_Protein_Collection_Info',
												@IncrementRefreshCount = 1, 
												@FullRefreshPerformed = 1, 
												@LastRefreshMinimumID = 0
		End

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedProteinCollectionInfo')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch


	Begin Try
		truncate table #Tmp_UpdateSummary
				
		Set @CurrentLocation = 'Update Last_Refreshed in T_DMS_Cached_Data_Status'
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Protein_Collection_AOF_Stats', @IncrementRefreshCount = 0, @FullRefreshPerformed = 1, @LastRefreshMinimumID = 0


		Set @CurrentLocation = 'Merge data into T_DMS_Protein_Collection_AOF_Stats'

		-- Use a MERGE Statement to synchronize T_DMS_Protein_Collection_AOF_Stats with V_Protein_Collection_List_Export
		--
		 MERGE T_DMS_Protein_Collection_AOF_Stats AS target
		 USING (SELECT PCFS.Archived_File_ID, PCFS.Filesize,
                       PCFS.Protein_Collection_Count,
                       PCFS.Protein_Count, PCFS.Residue_Count,
                       PCFS.Archived_File_Name 
		        FROM V_DMS_Protein_Collection_File_Stats_Import PCFS	
			) AS Source ( Archived_File_ID, Filesize, Protein_Collection_Count,
                          Protein_Count, Residue_Count, Archived_File_Name)
		 ON (target.Archived_File_ID = source.Archived_File_ID)
		 WHEN Matched AND ( Target.Filesize <> Source.Filesize OR
		                    IsNull(Target.Protein_Collection_Count, 0) <> IsNull(Source.Protein_Collection_Count, 0) OR
		                    IsNull(Target.Protein_Count, 0)            <> IsNull(Source.Protein_Count, 0) OR
		      IsNull(Target.Residue_Count, 0)            <> IsNull(Source.Residue_Count, 0) OR
		                    Target.Archived_File_Name                  <> Source.Archived_File_Name) THEN 
			UPDATE Set 
		          Filesize = Source.Filesize,
		          Protein_Collection_Count = IsNull(Source.Protein_Collection_Count, 0),
		          Protein_Count = IsNull(Source.Protein_Count, 0),
		          Residue_Count = IsNull(Source.Residue_Count, 0),
		          Archived_File_Name = Source.Archived_File_Name,
		          Last_Affected = GetDate()
		 WHEN Not Matched THEN
			INSERT ( Archived_File_ID, Filesize, Protein_Collection_Count,
                     Protein_Count, Residue_Count,
                     Archived_File_Name, Last_Affected)
			VALUES ( Source.Archived_File_ID, Source.Filesize, Source.Protein_Collection_Count,
		             Source.Protein_Count, Source.Residue_Count,
                     Source.Archived_File_Name, GetDate())
		 WHEN NOT MATCHED BY SOURCE THEN
			DELETE
		 OUTPUT $action INTO #Tmp_UpdateSummary
		 ;
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myError <> 0
		Begin
			set @message = 'Error merging V_Protein_Collection_List_Import with T_DMS_Protein_Collection_AOF_Stats (ErrorID = ' + Convert(varchar(12), @myError) + ')'
			execute PostLogEntry 'Error', @message, 'RefreshCachedProteinCollectionInfo'
		End
		Else
		Begin

			-- Update the stats in T_DMS_Cached_Data_Status
			exec RefreshCachedDMSInfoFinalize 'RefreshCachedProteinCollectionInfo', 'V_DMS_Protein_Collection_File_Stats_Import', 'T_DMS_Protein_Collection_AOF_Stats',
												@IncrementRefreshCount = 1, 
												@FullRefreshPerformed = 1, 
												@LastRefreshMinimumID = 0
		End

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedProteinCollectionInfo')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList=53,
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch


Done:
	Return @myError

GO
