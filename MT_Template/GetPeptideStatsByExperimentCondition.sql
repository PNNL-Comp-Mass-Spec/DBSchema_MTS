/****** Object:  StoredProcedure [dbo].[GetPeptideStatsByExperimentCondition] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure GetPeptideStatsByExperimentCondition
/****************************************************
**
**	Desc: 
**		Returns details on the peptides present in each of 3 experimental conditions (Global, Soluble, and Insoluble)
**		If the ConditionDSFilter parameters are blank and @DatasetToConditionMapTable is blank, then uses 
**		  T_Process_Config to determine the filter strings
**		Note: When using the ConditionDSFilter parameters, a dataset will not be allowed to belong in multiple conditions.
**		 If a dataset matches the filter text for multiple conditions, it will only be mapped to the first condition it matches
**
**		If the @DatasetToConditionMapTable parameter is defined, then will use the given table for the Dataset to Condition mapping
**			If @DatasetToConditionMapTable is used, it must have columns Condition_Name and Dataset_ID
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	05/01/2008
**			05/05/2008 mem - Updated to treat null Peptide_Prophet_Probability values as 0
**			11/05/2008 mem - Added support for Inspect results (type IN_Peptide_Hit)
**    
*****************************************************/
(
	@GlobalConditionDSFilter varchar(4000) = 'Experiment LIKE ''%SBalt[0-9][0-9][0-9]_1%''',		-- Valid where clause to use when querying T_Analysis_Description; Ignored if @DatasetToConditionMapTable is defined
	@SolubleConditionDSFilter varchar(4000) = 'Experiment LIKE ''%SBalt[0-9][0-9][0-9]_2%''',		-- Valid where clause to use when querying T_Analysis_Description; Ignored if @DatasetToConditionMapTable is defined
	@InsolubleConditionDSFilter varchar(4000) = 'Experiment LIKE ''%SBalt[0-9][0-9][0-9]_3%''',		-- Valid where clause to use when querying T_Analysis_Description; Ignored if @DatasetToConditionMapTable is defined
	@DatasetToConditionMapTable varchar(256) = '',												-- Optional: Table that maps Condition Name to Dataset_ID
	@MTIDMin int = 0,									-- If non-zero, then will use this to filter the MTs
	@MTIDMax int = 0,									-- If non-zero, then will use this to filter the MTs
	@BaseMTFilterNumPeptides int = 3,
	@BaseMTFilterMinDiscriminant real = 0.85,
	@BaseMTFilterMinPepProphet real = 0,
	@BaseMTFilterMinPeptideLength int = 6,
	@message varchar(255)='' OUTPUT,
	@PreviewConditionToDatasetMap tinyint = 0,
	@PreviewSql tinyint = 0
)
AS

	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @S varchar(max)
	Declare @CreateObsCounts varchar(max)
	Declare @CreateObsCountsFilt varchar(max)
	
	Declare @ObservationCountColumnNameList varchar(max)
	Declare @ObservationCountPivotSumList varchar(max)
	Declare @ObservationCountColumnSumList varchar(max)

	Declare @ObsCountsColumnList varchar(max)
	Declare @ObsCountsFilteredColumnList varchar(max)
	
	Declare @CurrentColumn varchar(164)
	
	Declare @ConditionDSFilter varchar(4000)
	Declare @ConditionName varchar(128)
	Declare @ConditionID int
	
	Declare @Continue tinyint
	Declare @ConditionIteration int
	Declare @ConditionCount int

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		---------------------------------------------------
		-- Validate the inputs
		---------------------------------------------------

		Set @GlobalConditionDSFilter = IsNull(@GlobalConditionDSFilter, '')
		Set @SolubleConditionDSFilter = IsNull(@SolubleConditionDSFilter, '')
		Set @InsolubleConditionDSFilter = IsNull(@InsolubleConditionDSFilter, '')
		Set @DatasetToConditionMapTable = IsNull(@DatasetToConditionMapTable, '')
		
		Set @MTIDMin = IsNull(@MTIDMin, 0)
		Set @MTIDMax = IsNull(@MTIDMax, 0)
		
		Set @BaseMTFilterNumPeptides = IsNull(@BaseMTFilterNumPeptides, 3)
		Set @BaseMTFilterMinDiscriminant = IsNull(@BaseMTFilterMinDiscriminant, 0.85)
		Set @BaseMTFilterMinPepProphet = IsNull(@BaseMTFilterMinPepProphet, 0)
		Set @BaseMTFilterMinPeptideLength = IsNull(@BaseMTFilterMinPeptideLength, 6)


		Set @message= ''
		Set @PreviewConditionToDatasetMap = IsNull(@PreviewConditionToDatasetMap, 0)
		Set @PreviewSql = IsNull(@PreviewSql, 0)
		
		---------------------------------------------------
		-- Create the temporary tables
		---------------------------------------------------
		
		Set @CurrentLocation = 'Create the temporary tables'
		
		-- Create (or clear) the table to track the conditions
		IF Exists (select * from sys.tables where name = '#Tmp_DatasetIDList')
		Begin
			If @PreviewSql = 0
				Truncate Table #Tmp_DatasetIDList
		End
		Else
		Begin
			CREATE TABLE #Tmp_DatasetIDList (
				Dataset_ID int NOT NULL
			)
			
			CREATE UNIQUE INDEX #IX_Tmp_DatasetIDList ON #Tmp_DatasetIDList (Dataset_ID ASC)
		End


		-- Create (or clear) the table to track the conditions
		IF Exists (select * from sys.tables where name = '#Tmp_Condition_to_DS_Map')
		Begin
			If @PreviewSql = 0
				Truncate Table #Tmp_Condition_to_DS_Map
		End
		Else
		Begin
			CREATE TABLE #Tmp_Condition_to_DS_Map (
				Condition_Name varchar(128) not null,
				Dataset_ID int
			)
			
			CREATE UNIQUE INDEX #IX_Tmp_Condition_to_DS_Map_DatasetID ON #Tmp_Condition_to_DS_Map (Dataset_ID ASC)
			CREATE UNIQUE INDEX #IX_Tmp_Condition_to_DS_Map_Condition_to_Dataset ON #Tmp_Condition_to_DS_Map (Condition_Name, Dataset_ID ASC)
		End

		IF Exists (select * from sys.tables where name = '#Tmp_Conditions')
			Truncate Table #Tmp_Conditions
		Else
		Begin
			CREATE TABLE #Tmp_Conditions (
				Condition_ID int Identity(1,1),
				Condition_Name varchar(128) not null,
			)
			
			CREATE UNIQUE INDEX #IX_Tmp_Conditions_Condition_Name ON #Tmp_Conditions (Condition_Name ASC)
			CREATE UNIQUE INDEX #IX_Tmp_Conditions_Condition_ID ON #Tmp_Conditions (Condition_ID ASC)
		End
			
		-- Create (or clear) #Tmp_MTIDsToUse
		IF Exists (select * from sys.tables where name = '#Tmp_MTIDsToUse')
		Begin
			If @PreviewSql = 0
				Truncate Table #Tmp_MTIDsToUse
		End
		Else
		Begin
			CREATE TABLE #Tmp_MTIDsToUse (
				Mass_Tag_ID int NOT NULL			
			)
			
			CREATE UNIQUE INDEX #IX_Tmp_MTIDsToUse ON #Tmp_MTIDsToUse (Mass_Tag_ID ASC)
		End

		-- Create (or clear) #Tmp_BaseData
		IF Exists (select * from sys.tables where name = '#Tmp_BaseData')
		Begin
			If @PreviewSql = 0
				Truncate Table #Tmp_BaseData
		End
		Else
		Begin
			CREATE TABLE #Tmp_BaseData (
				Mass_Tag_ID int NOT NULL,
				Observation_Count int NULL,
				Observation_Count_CurrentConditions int NULL,
				Peptide_Obs_Count_Passing_Filter int NULL,
				Peptide_Obs_Count_Passing_Filter_CurrentConditions int NULL,
				High_Discriminant_Score real NULL,
				Monoisotopic_Mass float NULL,
				Prefix_Residue varchar(1) NULL,
				Peptide varchar(850) NOT NULL,
				Suffix_Residue varchar(1) NULL,
				Orf_Count int NULL,
				Reference varchar(128) NOT NULL,
				Cleavage_State tinyint NULL,
				Terminus_State tinyint NULL,
				Residue_Start int NULL,
				Residue_End int NULL,
				Protein_Length int NULL,
				Miscleavage_Event_Loc varchar(24) NULL
			)
			
			CREATE INDEX #IX_Tmp_BaseData_Mass_Tag_ID ON #Tmp_BaseData (Mass_Tag_ID)
			
			CREATE UNIQUE INDEX #IX_Tmp_BaseData ON #Tmp_BaseData (Mass_Tag_ID, Reference ASC)
		End

		If Len(@DatasetToConditionMapTable) = 0
		Begin
			If Len(@GlobalConditionDSFilter) = 0
			Begin
				-- ToDo: Lookup the value for @GlobalConditionDSFilter in T_Process_Config
				
				Set @message = '@GlobalConditionDSFilter is blank; ToDo: Lookup this value in T_Process_Config (not yet implemented)'
				Set @myError = 50000
				Goto Done
			End
			
			---------------------------------------------------
			-- Populate #Tmp_Condition_to_DS_Map with the datasets that are in each condition
			---------------------------------------------------
		
			Set @CurrentLocation = 'Populate #Tmp_Condition_to_DS_Map with the datasets in each condition'
		
			Set @ConditionIteration = 0
			While @ConditionIteration < 3
			Begin
				Set @ConditionName = ''
				
				If @ConditionIteration = 0
				Begin
					Set @ConditionName = 'Global'
					Set @ConditionDSFilter = @GlobalConditionDSFilter
				End
				
				If @ConditionIteration = 1
				Begin
					Set @ConditionName = 'Soluble'
					Set @ConditionDSFilter = @SolubleConditionDSFilter
				End
				
				If @ConditionIteration = 2
				Begin
					Set @ConditionName = 'Insoluble'
					Set @ConditionDSFilter = @InsolubleConditionDSFilter
				End
				
				If Len(@ConditionName) > 0
				Begin
					INSERT INTO #Tmp_Conditions (Condition_Name) VALUES (@ConditionName)
					
					If Len(@ConditionDSFilter) > 0
					Begin
						Begin Try
							TRUNCATE TABLE #Tmp_DatasetIDList
							
							Set @S = ''
							Set @S = @S + ' INSERT INTO #Tmp_DatasetIDList (Dataset_ID)'
							Set @S = @S + ' SELECT DISTINCT Dataset_ID '
							Set @S = @S + ' FROM T_Analysis_Description'
							Set @S = @S + ' WHERE ' + @ConditionDSFilter
							
							If @PreviewSql <> 0
								Print @S
							Else
								Exec (@S)
							--
							SELECT @myRowCount = @@RowCount, @myError = @@Error
							
						End Try
						Begin Catch
							-- Error caught; inform the user, set @PreviewConditionToDatasetMap to 1, then continue processing
							
							SELECT 'Error finding datasets for condition "' + @ConditionName + '"' AS Message, 
									@ConditionDSFilter AS Dataset_Filter,
									@S AS SqlText
							
							Set @PreviewConditionToDatasetMap = 1
						End Catch

						-- Add the new DatasetIDs to #Tmp_Condition_to_DS_Map, skipping any that are already present
						INSERT INTO #Tmp_Condition_to_DS_Map (Condition_Name, Dataset_ID)
						SELECT @ConditionName, D.Dataset_ID
						FROM #Tmp_DatasetIDList D LEFT OUTER JOIN
							#Tmp_Condition_to_DS_Map CDSM ON D.Dataset_ID = CDSM.Dataset_ID
						WHERE CDSM.Dataset_ID IS Null
						--
						SELECT @myRowCount = @@RowCount, @myError = @@Error						
					End
					Else
						Print 'Note: ConditionDSFilter is empty for Condition "' + @ConditionName + '" and will be ignored'
				End
							
				Set @ConditionIteration = @ConditionIteration + 1
			End

		End
		Else
		Begin
			---------------------------------------------------
			-- Copy the data from @DatasetToConditionMapTable to #Tmp_Condition_to_DS_Map
			---------------------------------------------------
			
			Set @CurrentLocation = 'Populate #Tmp_Condition_to_DS_Map using table @DatasetToConditionMapTable'
			
			Set @S = ''
			Set @S = @S + ' INSERT INTO #Tmp_Condition_to_DS_Map (Dataset_ID, Condition_Name)'
			Set @S = @S + ' SELECT Dataset_ID, MIN(Condition_Name)'
			Set @S = @S + ' FROM ' + @DatasetToConditionMapTable
			Set @S = @S + ' GROUP BY Dataset_ID'
			
			If @PreviewSql <> 0
				Print @S
			Else		
				Exec (@S)
			--
			SELECT @myRowCount = @@RowCount, @myError = @@Error
			
			-- Populate #Tmp_Conditions with the condition names in #Tmp_Condition_to_DS_Map
			INSERT INTO #Tmp_Conditions (Condition_Name)
			SELECT Condition_Name
			FROM #Tmp_Condition_to_DS_Map
			GROUP BY Condition_Name
			ORDER BY Condition_Name
			--
			SELECT @myRowCount = @@RowCount, @myError = @@Error
			
		End

		
		---------------------------------------------------
		-- Create #Tmp_Obs_Counts and #Tmp_Obs_Counts_Filtered
		---------------------------------------------------
		
		IF Exists (select * from sys.tables where name = '#Tmp_Obs_Counts')
			DROP Table #Tmp_Obs_Counts
		
		IF Exists (select * from sys.tables where name = '#Tmp_Obs_Counts_Filtered')
			DROP Table #Tmp_Obs_Counts_Filtered

		---------------------------------------------------
		-- First create the tables with just the Mass_Tag_ID column
		---------------------------------------------------
		CREATE TABLE #Tmp_Obs_Counts (Mass_Tag_ID int NOT NULL)
		CREATE TABLE #Tmp_Obs_Counts_Filtered (Mass_Tag_ID int NOT NULL)


		---------------------------------------------------
		-- Now loop through the data in #Tmp_Conditions to generate the list of
		-- columns to add to the tables
		---------------------------------------------------

		Set @CurrentLocation = 'Generate the comma separated condition lists'

		-- Initialize the variables
		Set @S = ''
		Set @ObservationCountColumnNameList = ''
		Set @ObservationCountPivotSumList = ''
		Set @ObservationCountColumnSumList = ''
		Set @ObsCountsColumnList = ''
		Set @ObsCountsFilteredColumnList = ''

		Set @ConditionID = 0
		Set @ConditionCount = 0
		
		Set @Continue = 1
		While @Continue = 1
		Begin
			SELECT TOP 1 @ConditionName = Condition_Name,
						@ConditionID = Condition_ID
			FROM #Tmp_Conditions
			WHERE Condition_ID > @ConditionID
			ORDER BY Condition_ID
			--
			SELECT @myRowCount = @@RowCount, @myError = @@Error
			
			If @myRowCount = 0
				Set @Continue = 0
			Else
			Begin
				Set @CurrentColumn = '[' + @ConditionName + '_Observation_Count]'
				
				-- Append this column to @S (which will be used to Alter the #Tmp_Obs tables)
				If Len(@S) = 0
					Set @S = ' add '
				Else
					Set @S = @S + ', '
					
				Set @S = @S + @CurrentColumn + ' int'


				-- Append this column to the variables that will be used to populate the #Tmp_Obs tables
				If Len(@ObservationCountColumnNameList) > 0
				Begin
					Set @ObservationCountColumnNameList = @ObservationCountColumnNameList + ', '
					Set @ObservationCountPivotSumList = @ObservationCountPivotSumList + ', '
					Set @ObservationCountColumnSumList = @ObservationCountColumnSumList + ' + '
					
					Set @ObsCountsColumnList = @ObsCountsColumnList + ', '
					Set @ObsCountsFilteredColumnList = @ObsCountsFilteredColumnList + ', '
				End
					
				Set @ObservationCountColumnNameList = @ObservationCountColumnNameList + @CurrentColumn
				Set @ObservationCountPivotSumList = @ObservationCountPivotSumList + 'SUM(CASE WHEN Condition_Name = ''' + @ConditionName + ''' THEN 1 ELSE 0 END) AS ' + @CurrentColumn
				Set @ObservationCountColumnSumList = @ObservationCountColumnSumList + @CurrentColumn

				Set @ObsCountsColumnList =         @ObsCountsColumnList +         'O.' + @CurrentColumn
				Set @ObsCountsFilteredColumnList = @ObsCountsFilteredColumnList + 'F.' + @CurrentColumn + ' AS ' + '[' + @ConditionName + '_Obs_Count_Filtered]'
				
				Set @ConditionCount = @ConditionCount + 1
			End
			
		End

		Set @CreateObsCounts =     ' ALTER TABLE #Tmp_Obs_Counts ' + @S
		Set @CreateObsCountsFilt = ' ALTER TABLE #Tmp_Obs_Counts_Filtered ' + @S

		-- Create the tables
		If @PreviewSql <> 0
		Begin
			Print @CreateObsCounts
			Print @CreateObsCountsFilt
		End
		Else
		Begin
			Exec (@CreateObsCounts)
			Exec (@CreateObsCountsFilt)
		End	
		
		
		Set @CurrentLocation = 'Preview the data in #Tmp_Conditions and #Tmp_Condition_to_DS_Map'

		If @PreviewConditionToDatasetMap <> 0
		Begin
			---------------------------------------------------
			-- Preview the data in #Tmp_Conditions and #Tmp_Condition_to_DS_Map
			---------------------------------------------------
			
			SELECT C.Condition_ID,
				C.Condition_Name,
				IsNull(MapQ.Dataset_Count, 0) AS Dataset_Count
			FROM #Tmp_Conditions C
				LEFT OUTER JOIN ( SELECT Condition_Name,
										COUNT(*) AS Dataset_Count
								FROM #Tmp_Condition_to_DS_Map
				GROUP BY Condition_Name ) MapQ
				ON C.Condition_Name = MapQ.Condition_Name
			ORDER BY C.Condition_ID		
			--
			SELECT @myRowCount = @@RowCount, @myError = @@Error
			
			
			SELECT C.Condition_ID, 
				DSC.Condition_Name, 
				DSC.Dataset_ID,
				TAD.Dataset, Count(*) AS Job_Count
			FROM #Tmp_Conditions C
				INNER JOIN #Tmp_Condition_to_DS_Map DSC
				ON C.Condition_Name = DSC.Condition_Name
				INNER JOIN T_Analysis_Description TAD
				ON DSC.Dataset_ID = TAD.Dataset_ID
			GROUP BY C.Condition_ID, 
				DSC.Condition_Name, 
				DSC.Dataset_ID, 
				TAD.Dataset
			ORDER BY C.Condition_ID, TAD.Dataset

			--
			SELECT @myRowCount = @@RowCount, @myError = @@Error
			
			-- Do not continue processing if @previewSql is 0
			If @previewSql = 0
				Goto Done
		End

		
		---------------------------------------------------
		-- Fill #Tmp_MTIDsToUse with the MTIDs to use
		-- Filter using the @BaseMTFilter values
		---------------------------------------------------
		--
		Set @CurrentLocation = 'Fill #Tmp_MTIDsToUse with the MTIDs to use'

		Set @S = ''
		Set @S = @S + ' INSERT INTO #Tmp_MTIDsToUse (Mass_Tag_ID)'
		Set @S = @S + ' SELECT MT.Mass_Tag_ID'
		Set @S = @S + ' FROM T_Mass_Tags MT'
		Set @S = @S + ' WHERE MT.Number_Of_Peptides >= ' + Convert(varchar(12), @BaseMTFilterNumPeptides)

		If @BaseMTFilterMinDiscriminant > 0
			Set @S = @S +   ' AND IsNull(MT.High_Discriminant_Score, 0) >= ' + Convert(varchar(12), @BaseMTFilterMinDiscriminant)

		If @BaseMTFilterMinPepProphet > 0
			Set @S = @S +   ' AND IsNull(MT.High_Peptide_Prophet_Probability, 0) >= ' + Convert(varchar(12), @BaseMTFilterMinPepProphet)

		If @BaseMTFilterMinPeptideLength > 0
			Set @S = @S +   ' AND LEN(MT.Peptide) >= ' + Convert(varchar(12), @BaseMTFilterMinPeptideLength)

		If @MTIDMin <> 0
			Set @S = @S +   ' AND MT.Mass_Tag_ID >= ' + Convert(varchar(19), @MTIDMin)
		
		If @MTIDMax <> 0
			Set @S = @S +   ' AND MT.Mass_Tag_ID <= ' + Convert(varchar(19), @MTIDMax)

		If @PreviewSql <> 0
			Print @S
		Else		
			Exec (@S)
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error
		
		If @previewSql = 0
		Begin
			---------------------------------------------------
			-- Fill #Tmp_BaseData with the base data for the MTs in #Tmp_MTIDsToUse
			---------------------------------------------------
			--
			Set @CurrentLocation = 'Fill #Tmp_BaseData with the base data'
			
			INSERT INTO #Tmp_BaseData( Mass_Tag_ID,
								Observation_Count,
								Peptide_Obs_Count_Passing_Filter,
								High_Discriminant_Score,
								Monoisotopic_Mass,
								Prefix_Residue,
								Peptide,
								Suffix_Residue,
								Reference,
								Cleavage_State,
								Terminus_State,
								Residue_Start,
								Residue_End,
								Protein_Length )
			SELECT MT.Mass_Tag_ID,
				MT.Number_Of_Peptides AS Observation_Count,
				MT.Peptide_Obs_Count_Passing_Filter,
				MT.High_Discriminant_Score,
				MT.Monoisotopic_Mass,
				CASE
					WHEN Residue_Start > 1 THEN SUBSTRING(Protein_Sequence, Residue_Start - 1, 1)
					ELSE '-'
				END AS Prefix_Residue,
				MT.Peptide,
				CASE
					WHEN Residue_End < Prot.Protein_Residue_Count THEN 
						SUBSTRING(Protein_Sequence, Residue_End + 1, 1)
					ELSE '-'
				END AS Suffix_Residue,
				Prot.Reference,
				MTPM.Cleavage_State,
				MTPM.Terminus_State,
				MTPM.Residue_Start,
				MTPM.Residue_End,
				Prot.Protein_Residue_Count AS Protein_Length			-- Alternatively, use DATALENGTH(Prot.Protein_Sequence)
			FROM #Tmp_MTIDsToUse 
				INNER JOIN T_Mass_Tags MT
				ON MT.Mass_Tag_ID = #Tmp_MTIDsToUse.Mass_Tag_ID
				INNER JOIN T_Mass_Tag_to_Protein_Map MTPM
				ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
				INNER JOIN T_Proteins Prot
				ON MTPM.Ref_ID = Prot.Ref_ID
			--
			SELECT @myRowCount = @@RowCount, @myError = @@Error

			---------------------------------------------------
			-- Populate column Miscleavage_Event_Loc in #Tmp_BaseData
			---------------------------------------------------
			--
			Set @CurrentLocation = 'Populate column Miscleavage_Event_Loc in #Tmp_BaseData'
			
			UPDATE #Tmp_BaseData
			SET Miscleavage_Event_Loc = 
				CASE Cleavage_State
					WHEN 1 THEN	CASE 
									WHEN Prefix_Residue LIKE '[KR]' AND
										Peptide NOT LIKE 'P%' 
									THEN 'C'
									ELSE 'N'
									END
					WHEN 0 THEN 'Both'
					ELSE ''
					END
			--
			SELECT @myRowCount = @@RowCount, @myError = @@Error

			
			---------------------------------------------------
			-- Populate column ORF_Count in #Tmp_BaseData
			-- This is a count of the number of proteins that a given peptide maps to
			---------------------------------------------------
			--
			Set @CurrentLocation = 'Populate column ORF_Count in #Tmp_BaseData'
			
			UPDATE #Tmp_BaseData
			SET Orf_Count = ORfCountQ.Orf_Count
			FROM #Tmp_BaseData
				INNER JOIN ( SELECT #Tmp_BaseData.Mass_Tag_ID,
									COUNT(*) AS Orf_Count
							FROM #Tmp_BaseData
								INNER JOIN T_Mass_Tag_to_Protein_Map
									ON #Tmp_BaseData.Mass_Tag_ID = T_Mass_Tag_to_Protein_Map.Mass_Tag_ID
							GROUP BY #Tmp_BaseData.Mass_Tag_ID ) ORFCountQ
				ON #Tmp_BaseData.Mass_Tag_ID = ORFCountQ.Mass_Tag_ID
			--
			SELECT @myRowCount = @@RowCount, @myError = @@Error
		End
		
		---------------------------------------------------
		-- Populate #Tmp_Obs_Counts with the unfiltered counts, by condition
		-- The sum of these three columns should match T_Mass_Tags.Number_Of_Peptides
		-- Note: Linking in #Tmp_BaseData has the effect of only examining the Mass_Tag_ID values we ultimately care about
		---------------------------------------------------
		--
		Set @CurrentLocation = 'Populate #Tmp_Obs_Counts with the unfiltered counts, by condition'
				
		Set @S = ''
		Set @S = @S + ' INSERT INTO #Tmp_Obs_Counts ( Mass_Tag_ID, '
		Set @S = @S +   @ObservationCountColumnNameList + ')'

		Set @S = @S + ' SELECT Mass_Tag_ID, '
		Set @S = @S +   @ObservationCountPivotSumList
			
		Set @S = @S + ' FROM ( SELECT DS_Conditions.Condition_Name,'
		Set @S = @S +            ' TAD.Dataset_ID,'
		Set @S = @S +            ' Pep.Mass_Tag_ID,'
		Set @S = @S +            ' Pep.Scan_Number,'
		Set @S = @S +            ' Pep.Charge_State'
		Set @S = @S +        ' FROM T_Analysis_Description TAD'
		Set @S = @S +        ' INNER JOIN T_Peptides Pep'
		Set @S = @S +          ' ON TAD.Job = Pep.Analysis_ID'
		Set @S = @S +        ' INNER JOIN #Tmp_Condition_to_DS_Map DS_Conditions'
		Set @S = @S +          ' ON TAD.Dataset_ID = DS_Conditions.Dataset_ID'
		Set @S = @S +        ' INNER JOIN #Tmp_BaseData D'
		Set @S = @S +          ' ON Pep.Mass_Tag_ID = D.Mass_Tag_ID'
		Set @S = @S +        ' GROUP BY DS_Conditions.Condition_Name, TAD.Dataset_ID, Pep.Mass_Tag_ID,'
		Set @S = @S +                 ' Pep.Scan_Number, Pep.Charge_State '
		Set @S = @S +      ' ) UniqueObsQ'
		Set @S = @S + ' GROUP BY Mass_Tag_ID'
		
		If @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error


		---------------------------------------------------
		-- Populate #Tmp_Obs_Counts_Filtered with the filtered counts, by condition
		-- These are counts of the observations that pass the Filter_Set_ID 141:
		--	XCorr >= 1.9, 2.2, or 3.0 for 1+, 2+, or >=3+, Hyperscore >= 20, 15, or 27 for 1+, 2+, or >=3+, partially or fully tryptic or non-tryptic protein terminal peptide, min length 6
		-- The sum of these three columns should match T_Mass_Tags.Number_Of_Peptides
		--
		-- Note: The following query uses a Common Table Expression (CTE) named MassTagsQ that first determines the Mass Tag IDs to examine
		---------------------------------------------------
		--
		Set @CurrentLocation = 'Populate #Tmp_Obs_Counts_Filtered with the filtered counts, by condition'
		
		Set @S = ''
		Set @S = @S + ' WITH MassTagsQ (Mass_Tag_ID)'
		Set @S = @S + ' AS ('
		Set @S = @S +   ' SELECT DISTINCT MT.Mass_Tag_ID'
		Set @S = @S +   ' FROM T_Mass_Tag_to_Protein_Map MTPM'
		Set @S = @S +        ' INNER JOIN T_Mass_Tags MT'
		Set @S = @S +          ' ON MTPM.Mass_Tag_ID = MT.Mass_Tag_ID'
		Set @S = @S +        ' INNER JOIN #Tmp_BaseData D'
		Set @S = @S +          ' ON MT.Mass_Tag_ID = D.Mass_Tag_ID'
		Set @S = @S +   ' WHERE (MTPM.Cleavage_State >= 1) OR'
		Set @S = @S +         ' (MTPM.Terminus_State >= 1)'
		Set @S = @S + ' )'
		
		Set @S = @S + ' INSERT INTO #Tmp_Obs_Counts_Filtered ( '
		Set @S = @S +            ' Mass_Tag_ID,'
		Set @S = @S +                  @ObservationCountColumnNameList + ')'
		Set @S = @S + ' SELECT Mass_Tag_ID, '
		Set @S = @S +          @ObservationCountPivotSumList
		
		Set @S = @S + ' FROM ( SELECT Condition_Name,'
		Set @S = @S +               ' Mass_Tag_ID,'
		Set @S = @S +               ' Scan_Number'
		Set @S = @S +        ' FROM ('
		
					Set @S = @S + ' SELECT DS_Conditions.Condition_Name,'
					Set @S = @S +        ' TAD.Dataset_ID,'
					Set @S = @S +        ' SeqFilteredDataQ.Mass_Tag_ID,'
					Set @S = @S +        ' SeqFilteredDataQ.Scan_Number'
					Set @S = @S + ' FROM ( SELECT DISTINCT Pep.Analysis_ID,'
					Set @S = @S +                        ' Pep.Mass_Tag_ID,'
					Set @S = @S +                        ' Pep.Scan_Number'
					Set @S = @S +        ' FROM MassTagsQ'
					Set @S = @S +             ' INNER JOIN T_Peptides Pep'
					Set @S = @S +               ' ON MassTagsQ.Mass_Tag_ID = Pep.Mass_Tag_ID'
					Set @S = @S +             ' INNER JOIN T_Score_Sequest SS'
					Set @S = @S +               ' ON Pep.Peptide_ID = SS.Peptide_ID'
					Set @S = @S +             ' INNER JOIN T_Score_Discriminant SD'
					Set @S = @S +               ' ON Pep.Peptide_ID = SD.Peptide_ID'
					Set @S = @S +       ' WHERE IsNull(SD.Peptide_Prophet_Probability, 0) >= 0 AND'
					Set @S = @S +             ' ((Pep.Charge_State = 1  AND SS.XCorr >= 1.9) OR'
					Set @S = @S +              ' (Pep.Charge_State = 2  AND SS.XCorr >= 2.2) OR'
					Set @S = @S +              ' (Pep.Charge_State >= 3 AND SS.XCorr >= 3.0)) '
					Set @S = @S +      ' ) SeqFilteredDataQ'
					Set @S = @S +      ' INNER JOIN T_Analysis_Description TAD'
					Set @S = @S +        ' ON SeqFilteredDataQ.Analysis_ID = TAD.Job'
					Set @S = @S +      ' INNER JOIN #Tmp_Condition_to_DS_Map DS_Conditions'
					Set @S = @S +        ' ON TAD.Dataset_ID = DS_Conditions.Dataset_ID'
					
					Set @S = @S +  ' UNION'
					
					Set @S = @S + ' SELECT DS_Conditions.Condition_Name,'
					Set @S = @S +        ' TAD.Dataset_ID,'
					Set @S = @S +        ' XTFilteredDataQ.Mass_Tag_ID,'
					Set @S = @S +        ' XTFilteredDataQ.Scan_Number'
					Set @S = @S + ' FROM ( SELECT DISTINCT Pep.Analysis_ID,'
					Set @S = @S +                ' Pep.Mass_Tag_ID,'
					Set @S = @S +                ' Pep.Scan_Number'
					Set @S = @S +        ' FROM MassTagsQ'
					Set @S = @S +             ' INNER JOIN T_Peptides Pep'
					Set @S = @S +               ' ON MassTagsQ.Mass_Tag_ID = Pep.Mass_Tag_ID'
					Set @S = @S +             ' INNER JOIN T_Score_XTandem XT'
					Set @S = @S +               ' ON Pep.Peptide_ID = XT.Peptide_ID'
					Set @S = @S +             ' INNER JOIN T_Score_Discriminant SD'
					Set @S = @S +               ' ON Pep.Peptide_ID = SD.Peptide_ID'
					Set @S = @S +       ' WHERE IsNull(SD.Peptide_Prophet_Probability, 0) >= 0 AND'
					Set @S = @S +             ' ((Pep.Charge_State = 1  AND XT.Hyperscore >= 20) OR'
					Set @S = @S +              ' (Pep.Charge_State = 2  AND XT.Hyperscore >= 15) OR'
					Set @S = @S +              ' (Pep.Charge_State >= 3 AND XT.Hyperscore >= 17)) '
					Set @S = @S +      ' ) XTFilteredDataQ'
					Set @S = @S +      ' INNER JOIN T_Analysis_Description TAD'
					Set @S = @S +        ' ON XTFilteredDataQ.Analysis_ID = TAD.Job'
					Set @S = @S +      ' INNER JOIN #Tmp_Condition_to_DS_Map DS_Conditions'
					Set @S = @S +        ' ON TAD.Dataset_ID = DS_Conditions.Dataset_ID'

					Set @S = @S +  ' UNION'
					
					Set @S = @S + ' SELECT DS_Conditions.Condition_Name,'
					Set @S = @S +        ' TAD.Dataset_ID,'
					Set @S = @S +        ' INFilteredDataQ.Mass_Tag_ID,'
					Set @S = @S +        ' INFilteredDataQ.Scan_Number'
					Set @S = @S + ' FROM ( SELECT DISTINCT Pep.Analysis_ID,'
					Set @S = @S +                ' Pep.Mass_Tag_ID,'
					Set @S = @S +                ' Pep.Scan_Number'
					Set @S = @S +        ' FROM MassTagsQ'
					Set @S = @S +             ' INNER JOIN T_Peptides Pep'
					Set @S = @S +               ' ON MassTagsQ.Mass_Tag_ID = Pep.Mass_Tag_ID'
					Set @S = @S +             ' INNER JOIN T_Score_Inspect I'
					Set @S = @S +               ' ON Pep.Peptide_ID = I.Peptide_ID'
					Set @S = @S +             ' INNER JOIN T_Score_Discriminant SD'
					Set @S = @S +               ' ON Pep.Peptide_ID = SD.Peptide_ID'
					Set @S = @S +       ' WHERE IsNull(SD.Peptide_Prophet_Probability, 0) >= 0 AND'
					Set @S = @S +             ' ((Pep.Charge_State = 1  AND I.FScore >= 0) OR'
					Set @S = @S +              ' (Pep.Charge_State = 2  AND I.FScore >= 0) OR'
					Set @S = @S +              ' (Pep.Charge_State >= 3 AND I.FScore >= 0)) '
					Set @S = @S +      ' ) INFilteredDataQ'
					Set @S = @S +      ' INNER JOIN T_Analysis_Description TAD'
					Set @S = @S +        ' ON INFilteredDataQ.Analysis_ID = TAD.Job'
					Set @S = @S +      ' INNER JOIN #Tmp_Condition_to_DS_Map DS_Conditions'
					Set @S = @S +        ' ON TAD.Dataset_ID = DS_Conditions.Dataset_ID'
										
		Set @S = @S +             ' ) ObsQ'
		Set @S = @S +        ' GROUP BY Condition_Name, Dataset_ID, Mass_Tag_ID, Scan_Number'
		Set @S = @S +      ' ) UniqueObsQ'
		Set @S = @S + ' GROUP BY Mass_Tag_ID'
		
		If @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error


		-------------------------------------------------------------
		-- Populate Observation_Count_CurrentConditions in #Tmp_BaseData
		-------------------------------------------------------------
		
		Set @CurrentLocation = 'Populate Observation_Count_CurrentConditions in #Tmp_BaseData'
		
		Set @S = ''
		Set @S = @S + ' UPDATE #Tmp_BaseData'
		Set @S = @S + ' SET Observation_Count_CurrentConditions = O.TotalCount'
		Set @S = @S + ' FROM #Tmp_BaseData' 
		Set @S = @S +      ' INNER JOIN ('
		Set @S = @S +          ' SELECT Mass_Tag_ID, '
		Set @S = @S +                   @ObservationCountColumnSumList + ' As TotalCount'
		Set @S = @S +          ' FROM #Tmp_Obs_Counts'
		Set @S = @S +        ' ) O ON #Tmp_BaseData.Mass_Tag_ID = O.Mass_Tag_ID'
		
		If @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error

		-------------------------------------------------------------
		-- Populate Peptide_Obs_Count_Passing_Filter_CurrentConditions in #Tmp_BaseData
		-------------------------------------------------------------
		
		Set @CurrentLocation = 'Populate Peptide_Obs_Count_Passing_Filter_CurrentConditions in #Tmp_BaseData'
		
		Set @S = ''
		Set @S = @S + ' UPDATE #Tmp_BaseData'
		Set @S = @S + ' SET Peptide_Obs_Count_Passing_Filter_CurrentConditions = O.TotalCount'
		Set @S = @S + ' FROM #Tmp_BaseData' 
		Set @S = @S +      ' INNER JOIN ('
		Set @S = @S +          ' SELECT Mass_Tag_ID, '
		Set @S = @S +                   @ObservationCountColumnSumList + ' As TotalCount'
		Set @S = @S +          ' FROM #Tmp_Obs_Counts_Filtered'
		Set @S = @S +        ' ) O ON #Tmp_BaseData.Mass_Tag_ID = O.Mass_Tag_ID'
		
		If @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error

		-------------------------------------------------------------
		-- Link the three tables together to return the results
		-------------------------------------------------------------
		--
		Set @CurrentLocation = 'Return the results using #Tmp_BaseData, #Tmp_Obs_Counts, and #Tmp_Obs_Counts_Filtered'
		
		Set @S = ''
		Set @S = @S + ' SELECT D.Mass_Tag_ID,'
		-- Set @S = @S +        ' D.Observation_Count AS Obs_Count_from_T_Mass_Tags,'
		Set @S = @S +   ' D.Observation_Count_CurrentConditions,'
		-- Set @S = @S +        ' D.Peptide_Obs_Count_Passing_Filter AS Obs_Count_Passing_Filter_from_T_Mass_Tags,'
		Set @S = @S +        ' D.Peptide_Obs_Count_Passing_Filter_CurrentConditions,'
		Set @S = @S +        ' D.High_Discriminant_Score,'
		Set @S = @S +        ' D.Monoisotopic_Mass,'
		Set @S = @S +        ' D.Prefix_Residue,'
		Set @S = @S +        ' D.Peptide,'
		Set @S = @S +        ' D.Suffix_Residue,'
		Set @S = @S +        ' D.ORF_Count,'
		Set @S = @S +        ' D.Reference,'
		Set @S = @S +        ' D.Cleavage_State,'
		Set @S = @S +        ' D.Terminus_State,'
		Set @S = @S +        ' D.Miscleavage_Event_Loc,'
		Set @S = @S +        ' D.Residue_Start,'
		Set @S = @S +        ' D.Residue_End,'
		Set @S = @S +        ' D.Protein_Length,'
		Set @S = @S +        @ObsCountsColumnList + ','
		Set @S = @S +        @ObsCountsFilteredColumnList

		Set @S = @S + ' FROM #Tmp_BaseData D'
		Set @S = @S +      ' INNER JOIN #Tmp_Obs_Counts O'
		Set @S = @S +        ' ON D.Mass_Tag_ID = O.Mass_Tag_ID'
		Set @S = @S +      ' INNER JOIN #Tmp_Obs_Counts_Filtered F'
		Set @S = @S +        ' ON F.Mass_Tag_ID = D.Mass_Tag_ID'
		Set @S = @S + ' ORDER BY D.Cleavage_State DESC, D.Prefix_Residue, D.Peptide, D.Mass_Tag_ID, D.Reference'
		
		If @PreviewSql <> 0
			Print @S
		Else
			Exec (@S)
		--
		SELECT @myRowCount = @@RowCount, @myError = @@Error

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'GetPeptideStatsByExperimentCondition')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, 
								@ErrorNum = @myError output, @message = @message output
								
		If Len(IsNull(@S, '')) > 0
		Begin
			Print 'Most Recent Dynamic Sql:'
			Print @S
		End
		
		Goto Done
	End Catch
	
Done:

	If Len(@Message) > 0
	Begin
		If @PreviewConditionToDatasetMap <> 0 OR @PreviewSql <> 0
			Select @Message AS Message
	End
	
	Return @myError

GO
GRANT EXECUTE ON [dbo].[GetPeptideStatsByExperimentCondition] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetPeptideStatsByExperimentCondition] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetPeptideStatsByExperimentCondition] TO [MTS_DB_Lite] AS [dbo]
GO
