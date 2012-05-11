/****** Object:  StoredProcedure [dbo].[RefreshCachedDMSInfoIfRequired] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RefreshCachedDMSInfoIfRequired
/****************************************************
**
**	Desc: 
**		Calls the various RefreshCachedDMS procedures if the
**		Last_Refreshed date in T_DMS_Cached_Data_Status is over
**		@UpdateInterval hours before the present
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	05/09/2007 mem - See Ticket:422
**			09/18/2008 mem - Added parameters @DynamicMinimumCountThreshold and @UpdateIntervalAllItems
**			08/02/2010 mem - Now calling RefreshCachedDMSFilterSetInfo, RefreshCachedDMSResidues, and RefreshCachedDMSEnzymes
**			12/13/2010 mem - Now calling RefreshCachedProteinCollectionInfo
**			12/14/2010 mem - Now calling RefreshCachedOrganismDBInfo
**			10/17/2011 mem - Now setting @SourceMTSServer to '' when calling 'RefreshCachedDMSAnalysisJobInfo' or 'RefreshCachedDMSDatasetInfo'
**    
*****************************************************/
(
	@UpdateInterval real = 1,						-- Minimum interval in hours to limit update frequency; Set to 0 to force update now
	@DynamicMinimumCountThreshold int = 10000,		-- When updating every @UpdateInterval hours, uses the maximum cached ID value in the given T_DMS_%_Cached table to determine the minimum ID number to update; for example, for T_DMS_Analysis_Job_Info_Cached, MinimumJob = MaxJobInTable - @DynamicMinimumCountThreshold; set to 0 to update all items, regardless of ID
	@UpdateIntervalAllItems real = 24,				-- Interval (in hours) to update all items, regardless of ID
	@InfoOnly tinyint = 0,
 	@message varchar(255) = '' output
)
As
	Set NoCount On

	Declare @myRowCount int
	Declare @myError int
	Set @myRowCount = 0
	Set @myError = 0

	set @message = ''

	Declare @CurrentTime datetime
	Set @CurrentTime = GetDate()

	Declare @EntryID int
	Declare @Continue tinyint
	
	Declare @LastRefreshed datetime
	Declare @LastFullRefresh datetime

	Declare @CacheTable varchar(256)
	Declare @IDColumnName varchar(64)
	Declare @SP varchar(128)
	Declare @AlwaysFullRefresh tinyint
	Declare @AddnlParamsForSP varchar(256)

	Declare @S nvarchar(2048)
	Declare @Params nvarchar(256)

	Declare @IDMinimum int
	Declare @MaxID int
	Declare @HoursSinceLastRefresh decimal(9,3)
	Declare @HoursSinceLastFullRefresh decimal(9,3)
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'
	
	Begin Try
		Set @CurrentLocation = 'Validate the inputs'
		--
		Set @UpdateInterval = IsNull(@UpdateInterval, 1)
		Set @DynamicMinimumCountThreshold = IsNull(@DynamicMinimumCountThreshold, 10000)
		Set @UpdateIntervalAllItems = IsNull(@UpdateIntervalAllItems, 24)
		Set @InfoOnly = IsNull(@InfoOnly, 0)
		
		Set @message = ''
	
		-- Create and populate the table that lists the tables to update
		--
		CREATE TABLE #Tmp_CachedDMSInfoToUpdate (
			EntryID int Identity(1,1),
			CacheTable varchar(128),
			IDColumnName varchar(128),
			SP varchar(128),
			AlwaysFullRefresh tinyint Default 1,
			AddnlParamsForSP varchar(256) Default ''
		)
		
		-- Jobs and Datasets 
		--
		INSERT INTO #Tmp_CachedDMSInfoToUpdate (CacheTable, IDColumnName, SP, AlwaysFullRefresh, AddnlParamsForSP)
		VALUES ('T_DMS_Analysis_Job_Info_Cached', 'Job', 'RefreshCachedDMSAnalysisJobInfo', 0, '@SourceMTSServer=''''')

		INSERT INTO #Tmp_CachedDMSInfoToUpdate (CacheTable, IDColumnName, SP, AlwaysFullRefresh, AddnlParamsForSP)
		VALUES ('T_DMS_Dataset_Info_Cached', 'ID', 'RefreshCachedDMSDatasetInfo', 0, '@SourceMTSServer=''''')
		
		-- Mass correction factors and filter sets
		--
		INSERT INTO #Tmp_CachedDMSInfoToUpdate (CacheTable, IDColumnName, SP)
		VALUES ('T_DMS_Mass_Correction_Factors_Cached', 'Mass_Correction_ID', 'RefreshCachedDMSMassCorrectionFactors')
		
		INSERT INTO #Tmp_CachedDMSInfoToUpdate (CacheTable, IDColumnName, SP)
		VALUES ('T_DMS_Filter_Set_Overview_Cached', 'Filter_Set_ID', 'RefreshCachedDMSFilterSetInfo')

		-- Residues and enzymes
		--
		INSERT INTO #Tmp_CachedDMSInfoToUpdate (CacheTable, IDColumnName, SP)
		VALUES ('T_DMS_Residues_Cached', 'Residue_ID', 'RefreshCachedDMSResidues')

		INSERT INTO #Tmp_CachedDMSInfoToUpdate (CacheTable, IDColumnName, SP)
		VALUES ('T_DMS_Enzymes_Cached', 'Enzyme_ID', 'RefreshCachedDMSEnzymes')

		-- Fasta Files and Protein Collections
		INSERT INTO #Tmp_CachedDMSInfoToUpdate (CacheTable, IDColumnName, SP)
		VALUES ('T_DMS_Organism_DB_Info', 'ID', 'RefreshCachedOrganismDBInfo')

		INSERT INTO #Tmp_CachedDMSInfoToUpdate (CacheTable, IDColumnName, SP)
		VALUES ('T_DMS_Protein_Collection_Info', 'Protein_Collection_ID', 'RefreshCachedProteinCollectionInfo')

		-- Call each stored procedure to perform the update
		--
		Set @EntryID = 0
		Set @Continue = 1
		
		While @Continue = 1
		Begin -- <a>
		
			SELECT TOP 1 @EntryID = EntryID,
			             @CacheTable = CacheTable,
			             @IDColumnName = IDColumnName,
			             @SP = SP,
			             @AlwaysFullRefresh = AlwaysFullRefresh,
			             @AddnlParamsForSP = AddnlParamsForSP
			FROM #Tmp_CachedDMSInfoToUpdate
			WHERE  EntryID > @EntryID
			ORDER BY EntryID
			--
			SELECT @myRowCount = @@RowCount, @myError = @@Error


			If @myRowCount = 0
				Set @Continue = 0
			Else
			Begin -- <b>
				Set @CurrentLocation = 'Check refresh time for ' + @CacheTable

				Set @LastRefreshed = '1/1/2000'
				Set @LastFullRefresh = '1/1/2000'
				
				If @AlwaysFullRefresh = 0
				Begin
					SELECT  @LastRefreshed = Last_Refreshed,
							@LastFullRefresh = Last_Full_Refresh
					FROM T_DMS_Cached_Data_Status
					WHERE Table_Name = @CacheTable
					--
					SELECT @myRowCount = @@RowCount, @myError = @@Error

					Set @HoursSinceLastRefresh = DateDiff(minute, IsNull(@LastRefreshed, '1/1/2000'), @CurrentTime) / 60.0
					If @infoOnly <> 0
						Print 'Hours since last refresh: ' + Convert(varchar(12), @HoursSinceLastRefresh) + Case When @HoursSinceLastRefresh >= @UpdateInterval Then ' -> Partial refresh required' Else '' End

					Set @HoursSinceLastFullRefresh = DateDiff(minute, IsNull(@LastFullRefresh, '1/1/2000'), @CurrentTime) / 60.0
					If @infoOnly <> 0
						Print 'Hours since last full refresh: ' + Convert(varchar(12), @HoursSinceLastFullRefresh) + Case When @HoursSinceLastFullRefresh >= @UpdateIntervalAllItems Then ' -> Full refresh required' Else '' End
				End
				
				If @AlwaysFullRefresh <> 0 OR @HoursSinceLastRefresh >= @UpdateInterval OR @HoursSinceLastFullRefresh >= @UpdateIntervalAllItems
				Begin -- <c>
				
					Set @IDMinimum = 0
					If @AlwaysFullRefresh = 0 AND @HoursSinceLastFullRefresh < @UpdateIntervalAllItems
					Begin
						-- Less than @UpdateIntervalAllItems hours has elapsed since the last full update
						-- Bump up @IDMinimum to @DynamicMinimumCountThreshold less than the max ID in the target table
						
						Set @S = 'SELECT @MaxID = MAX([' + @IDColumnName + ']) FROM ' + @CacheTable
						
						-- Params string for sp_ExecuteSql
						Set @Params = '@MaxID int output'
						
						Set @MaxID = 0
						exec sp_executesql @S, @Params, @MaxID = @MaxID output
						
						If IsNull(@MaxID, 0) > 0
						Begin
							Set @IDMinimum = @MaxID - @DynamicMinimumCountThreshold
							If @IDMinimum < 0
								Set @IDMinimum = 0
								
							If @InfoOnly <> 0
								Print 'MaxID in ' + @CacheTable + ' is ' + Convert(Varchar(12), @MaxID) + '; will set minimum to ' + Convert(varchar(12), @IDMinimum)
						End
					End

					Set @S = 'Exec ' + @SP

					If @IDMinimum <> 0
					Begin
						If Len(@AddnlParamsForSP) > 0
							Set @AddnlParamsForSP = Convert(varchar(12), @IDMinimum) + ', ' + @AddnlParamsForSP
						Else
							Set @AddnlParamsForSP = Convert(varchar(12), @IDMinimum)
					End
					
					If Len(@AddnlParamsForSP) > 0
						Set @S = @S + ' ' + @AddnlParamsForSP
					
					If @InfoOnly = 0
						Exec (@S)
					Else
					Begin
						If @AlwaysFullRefresh = 0
							Print 'Need to call ' + @SP + ' since last refreshed ' + Convert(varchar(32), @LastRefreshed) + '; ' + @S
						Else
							Print 'Need to call ' + @SP + ' since @AlwaysFullRefresh = 1; ' + @S
					End
						
				End -- </c>
			End -- </b>
			
			If @infoOnly <> 0
				Print ''
				
		End -- </a>
				
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedDMSInfoIfRequired')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch
			
Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSInfoIfRequired] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSInfoIfRequired] TO [MTS_DB_Lite] AS [dbo]
GO
