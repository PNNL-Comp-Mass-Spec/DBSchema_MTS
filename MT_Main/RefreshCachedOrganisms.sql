/****** Object:  StoredProcedure [dbo].[RefreshCachedOrganisms] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE RefreshCachedOrganisms
/****************************************************
**
**	Desc:	Updates the data in T_DMS_Organisms
**			using V_DMS_Organisms_Import
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	08/01/2012 mem - Initial version
**			10/10/2013 mem - Added parameter @UpdateCachedDataStatusTable
**			09/23/2014 mem - Now treating error 53 as a warning (Named Pipes Provider: Could not open a connection to SQL Server)
**
*****************************************************/
(
	@UpdateCachedDataStatusTable tinyint = 1,
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
	
	Set @UpdateCachedDataStatusTable = IsNull(@UpdateCachedDataStatusTable, 1)
	
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
		Exec UpdateDMSCachedDataStatus 'T_DMS_Organisms', @IncrementRefreshCount = 0, @FullRefreshPerformed = 1, @LastRefreshMinimumID = 0

		Set @CurrentLocation = 'Merge data into T_DMS_Organisms'

		-- Use a MERGE Statement to synchronize T_DMS_Organisms with V_DMS_Organisms_Import
		--
		
		MERGE T_DMS_Organisms AS target
		USING (SELECT Organism_ID, [Name], Description, Short_Name,
		              Domain, Kingdom, Phylum, Class, [Order], Family, Genus, Species, Strain,
		              DNA_Translation_Table_ID, Mito_DNA_Translation_Table_ID, Created, Active, 
		              OrganismDBPath, OG_RowVersion
                FROM V_DMS_Organisms_Import
			) AS Source ( Organism_ID, [Name], Description, Short_Name,
						  Domain, Kingdom, Phylum, Class, [Order], Family, Genus, Species, Strain,
						  DNA_Translation_Table_ID, Mito_DNA_Translation_Table_ID, Created, Active, 
						  OrganismDBPath, OG_RowVersion )
		 ON (target.Organism_ID = source.Organism_ID)
		 WHEN Matched AND ( target.Cached_RowVersion <> Source.OG_RowVersion) THEN 
			UPDATE Set
					Organism_ID = Source.Organism_ID,
					[Name] = Source.Name,
					Description = Source.Description,
					Short_Name = Source.Short_Name,
					Domain = Source.Domain,
					Kingdom = Source.Kingdom,
					Phylum = Source.Phylum,
					Class = Source.Class,
					[Order] = Source.[Order],
					Family = Source.Family,
					Genus = Source.Genus,
					Species = Source.Species,
					Strain = Source.Strain,
					DNA_Translation_Table_ID = Source.DNA_Translation_Table_ID,
					Mito_DNA_Translation_Table_ID = Source.Mito_DNA_Translation_Table_ID,
					Created_DMS = Source.Created,
					Active = Source.Active,
					OrganismDBPath = Source.OrganismDBPath,
					Cached_RowVersion = OG_RowVersion,
					Last_Affected = GetDate()
		 WHEN Not Matched THEN
			INSERT ( Organism_ID, [Name], Description, Short_Name,
					 Domain, Kingdom, Phylum, Class, [Order], Family, Genus, Species, Strain,
					 DNA_Translation_Table_ID, Mito_DNA_Translation_Table_ID, Created_DMS, Active, 
					 OrganismDBPath, Cached_RowVersion, Last_Affected )
			VALUES ( Source.Organism_ID, Source.Name, Source.Description, Source.Short_Name,
					 Source.Domain, Source.Kingdom, Source.Phylum, Source.Class, Source.[Order], Source.Family, Source.Genus, Source.Species, Source.Strain,
 					 Source.DNA_Translation_Table_ID, Source.Mito_DNA_Translation_Table_ID, Source.Created, Source.Active, 
 					 Source.OrganismDBPath, Source.OG_RowVersion, GetDate())
		 WHEN NOT MATCHED BY SOURCE THEN
			DELETE
		 OUTPUT $action INTO #Tmp_UpdateSummary
		 ;
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		If @myError <> 0
		Begin
			set @message = 'Error merging V_DMS_Organisms_Import with T_DMS_Organisms (ErrorID = ' + Convert(varchar(12), @myError) + ')'
			execute PostLogEntry 'Error', @message, 'RefreshCachedOrganisms'
		End
		Else
		Begin

			If @UpdateCachedDataStatusTable <> 0
			Begin
				-- Update the stats in T_DMS_Cached_Data_Status
				exec RefreshCachedDMSInfoFinalize 'RefreshCachedOrganisms', 'V_DMS_Organisms_Import', 'T_DMS_Organisms',
												@IncrementRefreshCount = 1, 
												@FullRefreshPerformed = 1, 
												@LastRefreshMinimumID = 0
			End

		End

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedOrganisms')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList=53,
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch

Done:
	Return @myError

GO
