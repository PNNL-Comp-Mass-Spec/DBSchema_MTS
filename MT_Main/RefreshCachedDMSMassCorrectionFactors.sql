/****** Object:  StoredProcedure [dbo].[RefreshCachedDMSMassCorrectionFactors] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.RefreshCachedDMSMassCorrectionFactors
/****************************************************
**
**	Desc:	Updates the data in T_DMS_Mass_Correction_Factors_Cached using DMS
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	03/06/2007
**			05/09/2007 mem - Now calling UpdateDMSCachedDataStatus to update the cache status variables (Ticket:422)
**			09/18/2008 mem - Added parameters @MassCorrectionIDMinimum and @MassCorrectionIDMaximum
**						   - Now passing @FullRefreshPerformed and @LastRefreshMinimumID to UpdateDMSCachedDataStatus
**			07/30/2010 mem - Updated to use a single-step MERGE statement instead of three separate Delete, Update, and Insert statements
**			08/02/2010 mem - Updated to use V_DMS_Mass_Correction_Factors_Import to obtain the information from DMS
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
		Exec UpdateDMSCachedDataStatus 'T_DMS_Mass_Correction_Factors_Cached', @IncrementRefreshCount = 0, @FullRefreshPerformed = 1, @LastRefreshMinimumID = 0

		Set @CurrentLocation = 'Merge data into T_DMS_Mass_Correction_Factors_Cached'

		-- Use a MERGE Statement to synchronize T_DMS_Mass_Correction_Factors_Cached with V_DMS_Mass_Correction_Factors_Import
		--
		MERGE T_DMS_Mass_Correction_Factors_Cached AS target
		USING (SELECT Mass_Correction_ID,
                      Mass_Correction_Tag,
                      Description,
                      Monoisotopic_Mass_Correction,
                      Average_Mass_Correction,
                      Affected_Atom,
                      Original_Source,
                      Original_Source_Name,
                      Alternative_Name,
                      Empirical_Formula
               FROM V_DMS_Mass_Correction_Factors_Import
			) AS Source (  Mass_Correction_ID,
                           Mass_Correction_Tag,
                           Description,
                           Monoisotopic_Mass_Correction,
                           Average_Mass_Correction,
                           Affected_Atom,
                           Original_Source,
                           Original_Source_Name,
                           Alternative_Name,
                           Empirical_Formula)
		ON (target.Mass_Correction_ID = source.Mass_Correction_ID)
		WHEN Matched AND (  target.Mass_Correction_Tag <> source.Mass_Correction_Tag OR
				            IsNull(target.Description,'') <> IsNull(source.Description,'') OR
				            target.Monoisotopic_Mass_Correction <> source.Monoisotopic_Mass_Correction OR
				            IsNull(target.Average_Mass_Correction,0) <> IsNull(source.Average_Mass_Correction,0) OR
				            target.Affected_Atom <> source.Affected_Atom OR
				            IsNull(target.Empirical_Formula,'') <> IsNull(source.Empirical_Formula,'')) THEN 
			UPDATE set Mass_Correction_Tag = source.Mass_Correction_Tag, 
			           Description = source.Description, 
			           Monoisotopic_Mass_Correction = source.Monoisotopic_Mass_Correction,
			           Average_Mass_Correction = source.Average_Mass_Correction, 
			           Affected_Atom = source.Affected_Atom, 
			           Original_Source = source.Original_Source, 
			           Original_Source_Name = source.Original_Source_Name, 
			           Alternative_Name = source.Alternative_Name,
			           Empirical_Formula = source.Empirical_Formula
		WHEN Not Matched THEN
			INSERT (Mass_Correction_ID, Mass_Correction_Tag, Description, 
			        Monoisotopic_Mass_Correction, Average_Mass_Correction, 
			        Affected_Atom, Original_Source, Original_Source_Name, 
			        Alternative_Name, Empirical_Formula)
			VALUES (source.Mass_Correction_ID, source.Mass_Correction_Tag, 
			        source.Description, source.Monoisotopic_Mass_Correction, 
			        source.Average_Mass_Correction, source.Affected_Atom, 
			        source.Original_Source, source.Original_Source_Name, 
			        source.Alternative_Name, source.Empirical_Formula)
		WHEN NOT MATCHED BY SOURCE THEN 
			DELETE
		OUTPUT $action INTO #Tmp_UpdateSummary
		;
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		if @myError <> 0
		begin
			set @message = 'Error merging V_DMS_Mass_Correction_Factors_Import with T_DMS_Mass_Correction_Factors_Cached (ErrorID = ' + Convert(varchar(12), @myError) + ')'
			execute PostLogEntry 'Error', @message, 'RefreshCachedDMSMassCorrectionFactors'
		end

		-- Update the stats in T_DMS_Cached_Data_Status
		exec RefreshCachedDMSInfoFinalize 'RefreshCachedDMSMassCorrectionFactors', '', 'T_DMS_Mass_Correction_Factors_Cached'
				
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedDMSMassCorrectionFactors')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch
			
Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSMassCorrectionFactors] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[RefreshCachedDMSMassCorrectionFactors] TO [MTS_DB_Lite] AS [dbo]
GO
