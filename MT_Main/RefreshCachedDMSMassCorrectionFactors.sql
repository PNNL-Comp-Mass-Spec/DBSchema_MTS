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
**
*****************************************************/
(
	@MassCorrectionIDMinimum int = 0,		-- This parameter is not actually used, but is required for compatibility with the other RefreshCachedDMS procedures
	@MassCorrectionIDMaximum int = 0,		-- This parameter is not actually used, but is required for compatibility with the other RefreshCachedDMS procedures
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

	Begin Try
		Set @CurrentLocation = 'Update Last_Refreshed in T_DMS_Cached_Data_Status'
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Mass_Correction_Factors_Cached', @IncrementRefreshCount = 0, @FullRefreshPerformed = 1, @LastRefreshMinimumID = 0

		
		Set @CurrentLocation = 'Delete extra rows in T_DMS_Mass_Correction_Factors_Cached'
		-- 
		DELETE T_DMS_Mass_Correction_Factors_Cached
		FROM T_DMS_Mass_Correction_Factors_Cached Target LEFT OUTER JOIN
			 Gigasax.DMS5.dbo.T_Mass_Correction_Factors Src ON Target.Mass_Correction_ID = Src.Mass_Correction_ID
		WHERE (Src.Mass_Correction_ID IS NULL)
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error
		Set @DeleteCount = @myRowCount
		
		If @DeleteCount > 0
			Set @message = 'Deleted ' + convert(varchar(12), @DeleteCount) + ' extra rows'
			
		Set @CurrentLocation = 'Update existing rows in T_DMS_Mass_Correction_Factors_Cached'
		--
		UPDATE T_DMS_Mass_Correction_Factors_Cached
		SET Mass_Correction_Tag = Src.Mass_Correction_Tag, 
			Description = Src.Description, 
			Monoisotopic_Mass_Correction = Src.Monoisotopic_Mass_Correction,
			Average_Mass_Correction = Src.Average_Mass_Correction, 
			Affected_Atom = Src.Affected_Atom, 
			Original_Source = Src.Original_Source, 
			Original_Source_Name = Src.Original_Source_Name, 
			Alternative_Name = Src.Alternative_Name
		FROM T_DMS_Mass_Correction_Factors_Cached Target INNER JOIN
			 Gigasax.DMS5.dbo.T_Mass_Correction_Factors Src ON Target.Mass_Correction_ID = Src.Mass_Correction_ID
		WHERE (Target.Mass_Correction_Tag <> Src.Mass_Correction_Tag) OR
			  (IsNull(Target.Description,'') <> IsNull(Src.Description,'')) OR
			  (Target.Monoisotopic_Mass_Correction <> Src.Monoisotopic_Mass_Correction) OR
			  (IsNull(Target.Average_Mass_Correction,0) <> IsNull(Src.Average_Mass_Correction,0)) OR
			  (Target.Affected_Atom <> Src.Affected_Atom)
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error
		Set @UpdateCount = @myRowcount
		
		If @UpdateCount > 0
		Begin
			If Len(@message) > 0 
				Set @message = @message + '; '
			Set @message = @message + 'Updated ' + convert(varchar(12), @UpdateCount) + ' rows'
		End
		
		Set @CurrentLocation = 'Add new rows to T_DMS_Mass_Correction_Factors_Cached'
		--
		INSERT INTO T_DMS_Mass_Correction_Factors_Cached
			(Mass_Correction_ID, Mass_Correction_Tag, Description, 
			Monoisotopic_Mass_Correction, Average_Mass_Correction, 
			Affected_Atom, Original_Source, Original_Source_Name, 
			Alternative_Name)
		SELECT Src.Mass_Correction_ID, Src.Mass_Correction_Tag, 
			Src.Description, Src.Monoisotopic_Mass_Correction, 
			Src.Average_Mass_Correction, Src.Affected_Atom, 
			Src.Original_Source, Src.Original_Source_Name, 
			Src.Alternative_Name
		FROM T_DMS_Mass_Correction_Factors_Cached Target RIGHT OUTER JOIN
			 Gigasax.DMS5.dbo.T_Mass_Correction_Factors Src ON Target.Mass_Correction_ID = Src.Mass_Correction_ID
		WHERE (Target.Mass_Correction_ID IS NULL)
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error
		Set @InsertCount = @myRowcount
		
		If @InsertCount > 0
		Begin
			If Len(@message) > 0 
				Set @message = @message + '; '
			Set @message = @message + 'Added ' + convert(varchar(12), @InsertCount) + ' new rows'
		End
		
		If Len(@message) > 0 
		Begin	
			Set @message = 'Updated T_DMS_Mass_Correction_Factors_Cached: ' + @message
			execute PostLogEntry 'Normal', @message, 'RefreshCachedDMSMassCorrectionFactors'
		End

		Set @CurrentLocation = 'Update stats in T_DMS_Cached_Data_Status'
		-- 
		Exec UpdateDMSCachedDataStatus 'T_DMS_Mass_Correction_Factors_Cached', 
											@IncrementRefreshCount = 1, 
											@InsertCountNew = @InsertCount, 
											@UpdateCountNew = @UpdateCount, 
											@DeleteCountNew = @DeleteCount,
											@FullRefreshPerformed = 1, 
											@LastRefreshMinimumID = 0
		
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
