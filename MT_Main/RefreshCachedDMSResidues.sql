/****** Object:  StoredProcedure [dbo].[RefreshCachedDMSResidues] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[RefreshCachedDMSResidues]
/****************************************************
**
**	Desc:	Updates the data in T_DMS_Residues_Cached using DMS
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	08/02/2010 mem - Initial Version
**			09/23/2014 mem - Now treating error 53 as a warning (Named Pipes Provider: Could not open a connection to SQL Server)
**          02/12/2019 mem - Add column Amino_Acid_Name
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
		Exec UpdateDMSCachedDataStatus 'T_DMS_Residues_Cached', @IncrementRefreshCount = 0, @FullRefreshPerformed = 1, @LastRefreshMinimumID = 0

		Set @CurrentLocation = 'Merge data into T_DMS_Residues_Cached'

		-- Use a MERGE Statement to synchronize T_DMS_Residues_Cached with V_DMS_Residues_Import	
		--
		MERGE T_DMS_Residues_Cached AS target
		USING (	SELECT Residue_ID, Residue_Symbol,
					   Description,
					   Average_Mass, Monoisotopic_Mass,
					   Num_C, Num_H, Num_N, Num_O, Num_S,
					   Empirical_Formula, Amino_Acid_Name
				FROM V_DMS_Residues_Import
			) AS Source ( Residue_ID, Residue_Symbol,
						  Description,
						  Average_Mass, Monoisotopic_Mass,
						  Num_C, Num_H, Num_N, Num_O, Num_S,
						  Empirical_Formula, Amino_Acid_Name)
		ON (target.Residue_ID = source.Residue_ID)
		WHEN Matched AND (target.Residue_Symbol <> source.Residue_Symbol OR
					      target.Description <> source.Description OR
					      target.Average_Mass <> source.Average_Mass OR 
					      target.Monoisotopic_Mass <> source.Monoisotopic_Mass OR
					      target.Num_C <> source.Num_C OR
					      target.Num_H <> source.Num_H OR 
					      target.Num_N <> source.Num_N OR 
					      target.Num_O <> source.Num_O OR 
					      target.Num_S <> source.Num_S OR
					      IsNull(target.Empirical_Formula, '') <> IsNull(source.Empirical_Formula, '') OR
                          IsNull(target.Amino_Acid_Name, '') <> IsNull(source.Amino_Acid_Name, '')
						) THEN 
			UPDATE set Residue_Symbol = source.Residue_Symbol,
					   Description = source.Description,
					   Average_Mass = source.Average_Mass, 
					   Monoisotopic_Mass = source.Monoisotopic_Mass,
					   Num_C = source.Num_C,
					   Num_H = source.Num_H, 
					   Num_N = source.Num_N, 
					   Num_O = source.Num_O, 
					   Num_S = source.Num_S,
					   Empirical_Formula = source.Empirical_Formula,
                       Amino_Acid_Name = source.Amino_Acid_Name,
					   Last_Affected = GetDate()
		WHEN Not Matched THEN
			INSERT (Residue_ID, Residue_Symbol,
					   Description,
					   Average_Mass, Monoisotopic_Mass,
					   Num_C, Num_H, Num_N, Num_O, Num_S,
					   Empirical_Formula, Amino_Acid_Name, Last_Affected)
			VALUES (source.Residue_ID, 
					source.Residue_Symbol,
					source.Description,
					source.Average_Mass, 
					source.Monoisotopic_Mass,
					source.Num_C, source.Num_H, 
					source.Num_N, source.Num_O, source.Num_S,
					source.Empirical_Formula,
                    source.Amino_Acid_Name,
					GetDate())
		WHEN NOT MATCHED BY SOURCE THEN 
			DELETE
		OUTPUT $action INTO #Tmp_UpdateSummary
		;
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount

		if @myError <> 0
		begin
			set @message = 'Error merging V_DMS_Residues_Import with T_DMS_Residues_Cached (ErrorID = ' + Convert(varchar(12), @myError) + ')'
			execute PostLogEntry 'Error', @message, 'RefreshCachedDMSResidues'
		end

		-- Update the stats in T_DMS_Cached_Data_Status
		exec RefreshCachedDMSInfoFinalize 'RefreshCachedDMSResidues', '', 'T_DMS_Residues_Cached'
		
	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'RefreshCachedDMSResidues')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList=53,
								@ErrorNum = @myError output, @message = @message output
		Goto Done		
	End Catch
				
Done:

	drop table #Tmp_UpdateSummary
	
	Return @myError

GO
