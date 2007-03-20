/****** Object:  StoredProcedure [dbo].[QRSummary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure dbo.QRSummary
/****************************************************	
**  Desc: Returns a summary for task or tasks listed
**        in @QuantitationIDList
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: QuantitationID List to process
**
**  Auth:	mem
**	Date:	07/30/2003
**			08/01/2003 mem
**			08/15/2003 mem
**			08/22/2003 mem
**			08/26/2003 mem
**			09/22/2003 mem - Now returns Minimum_Criteria columns and looks up the Peak Matching Results path from MT_Main
**			11/19/2003 mem - Added the [Feature Count With Hits] column directly after the [Feature (UMC) Count] column
**			12/01/2003 mem - Now returns ReplicateNormalizationStats column
**			12/03/2003 mem - Added MassTag_Hit_Count > 0 to Where clause in query that computes @UMCCountWithHits
**			12/31/2003 mem - Now returns Total_Scans, Scan_Start, and Scan_End from T_FTICR_Analysis_Description
**						   - For replicates or other rolled-up data, returns the Average of Total_Scans, the Minimum of Scan_Start, and the Maximum of Scan_End
**			02/12/2004 mem - Now returns MD_Comparison_Mass_Tag_Count from T_Match_Making_Description
**			05/12/2004 mem - Updated to use udfPeakMatchingPathForMDID to construct the full path to the results folder
**			05/19/2004 mem - Moved location of the Results Folder Path folder to be directly after the jobs column
**			12/29/2004 mem - Removed Minimum_Criteria columns
**			04/13/2005 mem - Added parameter @VerboseColumnOutput and renamed some of the output columns
**			05/25/2005 mem - Now examining column GANET_Locker_Count, in addition to MassTag_Hit_Count
**						   - Now returning column UniqueInternalStdCount, in addition to UniqueMassTagCount; renamed column SampleName to [Sample Name]
**			06/16/2005 mem - Now returning list of MDIDs for each QID
**			07/28/2005 mem - Now obtaining Feature Count With Hits value from T_Quantitation_Description
**			08/25/2005 mem - Now returning Percent Features With Hits when @VerboseColumnOutput = 1
**			12/20/2005 mem - Renamed table T_FTICR_UMC_NETLockerDetails to T_FTICR_UMC_InternalStdDetails
**			03/13/2006 mem - Now sorting on Sample Name rather than QID
**			07/11/2006 mem - Now displaying the list of QIDs in the same order as defined in @QuantitationIDList (by default); set parameter @SortBySampleName to 1 to sort the list by sample name
**			09/14/2006 mem - Switched from SELECT DISTINCT to SELECT ... GROUP BY when populating @ExperimentList
**			11/29/2006 mem - Replaced parameter @SortBySampleName with parameter @SortMode, which affects the order in which the results are returned
**
****************************************************/
(
	@QuantitationIDList varchar(1024),			-- Comma separated list of Quantitation ID's
	@VerboseColumnOutput tinyint = 1,			-- Set to 1 to include all of the output columns; 0 to hide the less commonly used columns
	@SortMode tinyint=2							-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job)
)
AS 

	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Declare @WorkingList varchar(1024),
			@JobList varchar(1024),
			@MDIDList varchar(1024),
			@ExperimentList varchar(1024)
	
	Declare @CommaLoc int,
			@QuantitationID int,
			@JobListCount int,
			@UMCCountWithHits int

	Declare @TotalScanAvg int,
			@ScanStartMin int,
			@ScanEndMax int
	
	-- For each QuantitationID in @QuantitationIDList, determine the number of MDID's that were used
	-- If the MDID count is 1, then use a simple Select query
	-- If the MDID count is >1, then must use a Group By query
	
	-- First, create a temporary table to hold the results


	CREATE TABLE #QIDSummary (
		[UniqueRowID] [int] identity(1,1) NOT NULL,
		[Quantitation ID] [int] NOT NULL ,
		[Sample Name] [varchar] (255) NOT NULL ,
		[Comment] [varchar] (255) NOT NULL ,
		[Experiments] [varchar] (1024) NULL ,
		[Jobs] [varchar] (1024) NOT NULL ,
		[MDIDs] [varchar] (1024) NOT NULL ,
		[Results Folder Path] [varchar] (255) NULL ,
		[Fraction Highest Abu To Use] [decimal](9, 8) NOT NULL ,
		[Feature (UMC) Count] [int] NOT NULL ,
		[Feature Count With Hits] [int] NULL ,				-- This may be Null in Old Q Rollups
		[Percent Features With Hits] [real] NULL ,			-- This is simply [Feature Count With Hits] / [Feature (UMC) Count]
		[Unique PMT Tag Count Matched] [int] NULL ,
		[Unique Internal Std Count Matched] [int] NULL ,
		[Comparison PMT Tag Count] [int] NULL ,
		[MD UMC TolerancePPM] [numeric](9, 4) NOT NULL ,
		[MD NetAdj NET Min] [numeric](9, 5) NULL ,
		[MD NetAdj NET Max] [numeric](9, 5) NULL ,
		[MD MMA TolerancePPM] [numeric](9, 4) NULL ,
		[MD NET Tolerance] [numeric](9, 5) NULL ,
		[Refine Mass Cal PPMShift] [numeric](9, 4) NULL  ,
		[Total_Scans_Avg] [int] NULL ,
		[Scan_Start] [int] NULL ,
		[Scan_End] [int] NULL ,
		[ReplicateNormalizationStats] [varchar](1024) NULL		
	)
	
	-- Copy from @WorkingQIDList into @WorkingList
	Set @WorkingList = @QuantitationIDList + ','

	Set @CommaLoc = CharIndex(',', @WorkingList)
	WHILE @CommaLoc > 1
	BEGIN

		Set @QuantitationID = LTrim(Left(@WorkingList, @CommaLoc-1))
		Set @WorkingList = SubString(@WorkingList, @CommaLoc+1, Len(@WorkingList))
		
		If IsNumeric(@QuantitationID) = 1
		Begin
		
			-- Look up the job numbers and MDIDs that this QuantitationID corresponds to
			Set @JobList = ''
			Set @MDIDList = ''
			
			SELECT	@JobList = @JobList + ', ' + LTrim(RTrim(Convert(varchar(19), MMD.MD_Reference_Job))),
					@MDIDList = @MDIDList + ', ' + LTrim(RTrim(Convert(varchar(19), MMD.MD_ID)))
			FROM	T_Quantitation_Description AS QD INNER JOIN
					T_Quantitation_MDIDs AS QM ON QD.Quantitation_ID = QM.Quantitation_ID
					  INNER JOIN
					T_Match_Making_Description AS MMD ON QM.MD_ID = MMD.MD_ID
			WHERE	QD.Quantitation_ID = Convert(int, @QuantitationID)
			ORDER BY MD_Reference_Job
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			Set @JobListCount = @myRowCount
			
			If @JobListCount <= 0
			Begin
				-- This shouldn't happen
				Set @JobList = '0'
				Set @MDIDList = '0'
			End
			Else
			Begin
				-- Remove the leading , and space
				Set @JobList = SubString(@JobList, 3, Len(@JobList)-2)
				Set @MDIDList = SubString(@MDIDList, 3, Len(@MDIDList)-2)
			End
			

			If @JobListCount = 1
			  Begin
				-- Just one Job
				INSERT INTO #QIDSummary
					(	[Quantitation ID], [Sample Name], [Comment], [Experiments], 
						[Jobs],
						[MDIDs],
						[Results Folder Path],
						[Fraction Highest Abu To Use], 
						[Feature (UMC) Count], 
						[Feature Count With Hits], 
						[Percent Features With Hits],
						[Unique PMT Tag Count Matched], 
						[Unique Internal Std Count Matched], 
						[Comparison PMT Tag Count], 
						[MD UMC TolerancePPM], [MD NetAdj NET Min], [MD NetAdj NET Max],
						[MD MMA TolerancePPM], [MD NET Tolerance],
						[Refine Mass Cal PPMShift], 
						[Total_Scans_Avg], [Scan_Start], [Scan_End],
						[ReplicateNormalizationStats])
				SELECT QD.Quantitation_ID, QD.SampleName, QD.Comment, FAD.Experiment, 
				    CONVERT(varchar(19), MMD.MD_Reference_Job) AS Jobs, 
				    CONVERT(varchar(19), MMD.MD_ID) AS Jobs,
				    dbo.udfPeakMatchingPathForMDID(MMD.MD_ID) AS ResultsFolderPath,
				    QD.Fraction_Highest_Abu_To_Use, 
				    MMD.MD_UMC_Count, 
				    QD.FeatureCountWithMatchesAvg,
				    CASE WHEN MMD.MD_UMC_Count > 0 THEN IsNull(QD.FeatureCountWithMatchesAvg,0) / Convert(real, MMD.MD_UMC_Count) * 100 ELSE 0 END,
				    QD.UniqueMassTagCount, 
				    QD.UniqueInternalStdCount,
				    MMD.MD_Comparison_Mass_Tag_Count, 
				    MMD.MD_UMC_TolerancePPM, MMD.MD_NetAdj_NET_Min, MMD.MD_NetAdj_NET_Max, 
				    MMD.MD_MMA_TolerancePPM, MMD.MD_NET_Tolerance, 
				    MMD.Refine_Mass_Cal_PPMShift, 
					IsNull(FAD.Total_Scans, 0), IsNull(FAD.Scan_Start, 0), IsNull(FAD.Scan_End, 0),
					IsNull(QD.ReplicateNormalizationStats, '')
				FROM T_Quantitation_Description AS QD INNER JOIN
				    T_Quantitation_MDIDs ON 
				    QD.Quantitation_ID = T_Quantitation_MDIDs.Quantitation_ID
				     INNER JOIN
				    T_Match_Making_Description AS MMD ON 
				    T_Quantitation_MDIDs.MD_ID = MMD.MD_ID INNER JOIN
				    T_FTICR_Analysis_Description AS FAD ON 
				    MMD.MD_Reference_Job = FAD.Job
				WHERE (QD.Quantitation_ID = @QuantitationID)
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			  End
			Else
			  Begin
				-- Multiple Jobs
				-- Need to determine the experiments that these jobs belong to
				Set @ExperimentList = ''
				
				SELECT	@ExperimentList = @ExperimentList + ', ' + LTrim(RTrim(Convert(varchar(19), FAD.Experiment)))
				FROM	T_Quantitation_Description AS QD INNER JOIN
						T_Quantitation_MDIDs ON 
						QD.Quantitation_ID = T_Quantitation_MDIDs.Quantitation_ID
						  INNER JOIN
						T_Match_Making_Description AS MMD ON 
						T_Quantitation_MDIDs.MD_ID = MMD.MD_ID
					      INNER JOIN
					    T_FTICR_Analysis_Description AS FAD ON 
					    MMD.MD_Reference_Job = FAD.Job
				WHERE	QD.Quantitation_ID = Convert(int, @QuantitationID)
				GROUP BY FAD.Experiment
				ORDER BY FAD.Experiment
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				-- Remove the leading comma
				IF Len(@ExperimentList) > 0
					Set @ExperimentList = SubString(@ExperimentList, 3, Len(@ExperimentList)-2)

				-- Need to determine average Total Scans, minimum Scan_Start, and maximum Scan_End
				-- Note that Null values are ignored when computing the average, minimum, or maximum
				-- Consequently, if any of the jobs has a null value for any of these 3 fields, then the following warning message
				--  may be displayed: Null value is eliminated by an aggregate or other SET operation.
				SELECT	@TotalScanAvg = Convert(int, IsNull(Avg(FAD.Total_Scans), 0)), 
						@ScanStartMin = Convert(int, IsNull(Min(FAD.Scan_Start), 0)), 
						@ScanEndMax = Convert(int, IsNull(Max(FAD.Scan_End), 0))
				FROM	T_Quantitation_Description AS QD INNER JOIN
						T_Quantitation_MDIDs ON 
						QD.Quantitation_ID = T_Quantitation_MDIDs.Quantitation_ID
						  INNER JOIN
						T_Match_Making_Description AS MMD ON 
						T_Quantitation_MDIDs.MD_ID = MMD.MD_ID
					 INNER JOIN
					    T_FTICR_Analysis_Description AS FAD ON 
					    MMD.MD_Reference_Job = FAD.Job
				WHERE	QD.Quantitation_ID = Convert(int, @QuantitationID)
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				
				INSERT INTO #QIDSummary
					(	[Quantitation ID], [Sample Name], [Comment], [Experiments], 
						[Jobs], [MDIDs],
						[Results Folder Path],
						[Fraction Highest Abu To Use], [Feature (UMC) Count], 
						[Feature Count With Hits], 
						[Percent Features With Hits],
						[Unique PMT Tag Count Matched], 
						[Unique Internal Std Count Matched],
						[Comparison PMT Tag Count], 
						[MD UMC TolerancePPM], [MD NetAdj NET Min], [MD NetAdj NET Max],
						[MD MMA TolerancePPM], [MD NET Tolerance],
						[Refine Mass Cal PPMShift], 
						[Total_Scans_Avg], [Scan_Start], [Scan_End],
						[ReplicateNormalizationStats])
				SELECT QD.Quantitation_ID, QD.SampleName, QD.Comment, @ExperimentList, 
					@JobList, @MDIDList,
				    dbo.udfPeakMatchingPathForMDID(MIN(MMD.MD_ID)),
				    QD.Fraction_Highest_Abu_To_Use, 
				    AVG(MMD.MD_UMC_Count),
				    AVG(QD.FeatureCountWithMatchesAvg),
				    CASE WHEN AVG(MMD.MD_UMC_Count) > 0 THEN IsNull(AVG(QD.FeatureCountWithMatchesAvg), 0) / Convert(real, AVG(MMD.MD_UMC_Count)) * 100 ELSE 0 END,
				    QD.UniqueMassTagCount, 
				    QD.UniqueInternalStdCount,
				    AVG(MMD.MD_Comparison_Mass_Tag_Count),
				    AVG(MMD.MD_UMC_TolerancePPM),
				    AVG(MMD.MD_NetAdj_NET_Min),
				    AVG(MMD.MD_NetAdj_NET_Max),
				    AVG(MMD.MD_MMA_TolerancePPM),
				  AVG(MMD.MD_NET_Tolerance),
				    AVG(ABS(MMD.Refine_Mass_Cal_PPMShift)),
					@TotalScanAvg, @ScanStartMin, @ScanEndMax,
					IsNull(QD.ReplicateNormalizationStats, '')					
				FROM T_Quantitation_Description AS QD INNER JOIN
				    T_Quantitation_MDIDs ON 
				    QD.Quantitation_ID = T_Quantitation_MDIDs.Quantitation_ID
				     INNER JOIN
				    T_Match_Making_Description AS MMD ON 
				    T_Quantitation_MDIDs.MD_ID = MMD.MD_ID
				WHERE QD.Quantitation_ID = @QuantitationID
				GROUP BY QD.Quantitation_ID, 
				    QD.SampleName, 
				    QD.Comment, 
				    QD.Fraction_Highest_Abu_To_Use, 
				    QD.UniqueMassTagCount,
				    QD.UniqueInternalStdCount,
					QD.ReplicateNormalizationStats
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			  End
		    --End If
		    
		    -- Feature Count With Hits will be Null in old Q Rollups; check for this
		    
		    Set @UMCCountWithHits = -1
		    SELECT @UMCCountWithHits = IsNull([Feature Count With Hits], -1)
			FROM #QIDSummary


			If @UMCCountWithHits = -1
			Begin
				-- Feature Count With Hits is null, use the following to lookup the value
				-- This could be slightly off from what is computed in QuantitationProcessWork
				SELECT @UMCCountWithHits = AVG(UMCCountWithHits)
				FROM (	SELECT LookupQ.MD_ID, COUNT(DISTINCT LookupQ.UMC_Ind) AS UMCCountWithHits
						FROM (	SELECT	QMDID.Quantitation_ID, MMD.MD_ID, 
										FUR.UMC_Ind, RD.Mass_Tag_ID, 
										RD.Match_Score, RD.Del_Match_Score
								FROM T_Match_Making_Description AS MMD INNER JOIN
									T_Quantitation_MDIDs AS QMDID ON MMD.MD_ID = QMDID.MD_ID INNER JOIN
									T_FTICR_UMC_Results AS FUR ON MMD.MD_ID = FUR.MD_ID INNER JOIN
									T_FTICR_UMC_ResultDetails AS RD ON FUR.UMC_Results_ID = RD.UMC_Results_ID
								WHERE QMDID.Quantitation_ID = Convert(int, @QuantitationID) AND
									RD.Match_State = 6
								UNION
								SELECT	QMDID.Quantitation_ID, MMD.MD_ID, 
										FUR.UMC_Ind, ISD.Seq_ID, 
										ISD.Match_Score, ISD.Del_Match_Score
								FROM T_Match_Making_Description AS MMD INNER JOIN
									T_Quantitation_MDIDs AS QMDID ON MMD.MD_ID = QMDID.MD_ID INNER JOIN
									T_FTICR_UMC_Results AS FUR ON MMD.MD_ID = FUR.MD_ID INNER JOIN
									T_FTICR_UMC_InternalStdDetails AS ISD ON FUR.UMC_Results_ID = ISD.UMC_Results_ID
								WHERE QMDID.Quantitation_ID = Convert(int, @QuantitationID) AND
									ISD.Match_State = 6 
							) LookupQ INNER JOIN T_Quantitation_Description AS QD ON 
							LookupQ.Quantitation_ID = QD.Quantitation_ID AND 
							LookupQ.Match_Score >= QD.Minimum_Match_Score AND
							LookupQ.Del_Match_Score >= QD.Minimum_Del_Match_Score INNER JOIN 
							T_Mass_Tags AS MT ON 
							LookupQ.Mass_Tag_ID = MT.Mass_Tag_ID AND 
							MT.High_Normalized_Score >= QD.Minimum_MT_High_Normalized_Score AND 
							MT.High_Discriminant_Score >= QD.Minimum_MT_High_Discriminant_Score AND 
							MT.PMT_Quality_Score >= QD.Minimum_PMT_Quality_Score AND 
							LEN(MT.Peptide) >= QD.Minimum_Peptide_Length
						GROUP BY LookupQ.MD_ID
					) OuterQ
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				/*			
				** Old Method: Faster, but doesn't account for filters that may have been applied
				**
					SELECT @UMCCountWithHits = AVG(UMCCountWithHits)
					FROM (	SELECT COUNT(T_FTICR_UMC_Results.UMC_Ind) AS UMCCountWithHits
							FROM T_Match_Making_Description INNER JOIN
								T_Quantitation_MDIDs ON 
								T_Match_Making_Description.MD_ID = T_Quantitation_MDIDs.MD_ID
								INNER JOIN
								T_FTICR_UMC_Results ON 
								T_Match_Making_Description.MD_ID = T_FTICR_UMC_Results.MD_ID
							WHERE T_Quantitation_MDIDs.Quantitation_ID = Convert(int, @QuantitationID) AND
								(T_FTICR_UMC_Results.MassTag_Hit_Count > 0 OR T_FTICR_UMC_Results.InternalStd_Hit_Count > 0)
							GROUP BY T_Match_Making_Description.MD_ID, T_Quantitation_MDIDs.Quantitation_ID
						) AS CountsByMDID
				*/


				UPDATE #QIDSummary
				SET [Feature Count With Hits] = IsNull(@UMCCountWithHits,0)
				WHERE [Quantitation ID] = Convert(int, @QuantitationID)						

				UPDATE #QIDSummary
				SET [Percent Features With Hits] = [Feature Count With Hits] / Convert(real, [Feature (UMC) Count]) * 100
				WHERE [Quantitation ID] = Convert(int, @QuantitationID) AND [Feature (UMC) Count] > 0

		    End
      			
		End

		Set @CommaLoc = CharIndex(',', @WorkingList)
	END

	--------------------------------------------------------------
	-- Create two temporary tables
	--------------------------------------------------------------
	
	CREATE TABLE #TmpQIDValues (
		UniqueRowID int identity(1,1),
		QID int NOT NULL)
	
	CREATE TABLE #TmpQIDSortInfo (
		SortKey int identity (1,1),
		QID int NOT NULL)

	--------------------------------------------------------------
	-- Populate #TmpQIDValues with the values in @QuantitationIDList
	-- If @QuantitationIDList contains any non-numeric values, then this will throw an error
	--------------------------------------------------------------
	--
	INSERT INTO #TmpQIDValues (QID)
	SELECT [Quantitation ID]
	FROM #QIDSummary
	ORDER BY UniqueRowID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	
	If @myError <> 0
	Begin
		Goto Done
	End

	If @myRowCount = 0
	Begin
		-- No Data Found
		Set @myError = 50001
		Goto Done
	End
	
	--------------------------------------------------------------
	-- Populate #TmpQIDSortInfo based on @SortMode (using #TmpQIDValues)
	--------------------------------------------------------------
	Exec @myError = QRDetermineSortOrder @SortMode
	
	If @VerboseColumnOutput <> 0
	Begin
		SELECT 	[Quantitation ID],
				[Sample Name], [Comment], [Experiments],
				[Jobs], [MDIDs],
				[Results Folder Path],
				[Fraction Highest Abu To Use],
				[Feature (UMC) Count],
				[Feature Count With Hits], [Percent Features With Hits],
				[Unique PMT Tag Count Matched], [Unique Internal Std Count Matched],
				[Comparison PMT Tag Count],
				[MD UMC TolerancePPM],
				[MD NetAdj NET Min], [MD NetAdj NET Max],
				[MD MMA TolerancePPM], [MD NET Tolerance],
				[Refine Mass Cal PPMShift],
				[Total_Scans_Avg], [Scan_Start], [Scan_End],
				[ReplicateNormalizationStats]
		FROM #QIDSummary INNER JOIN 
			 #TmpQIDSortInfo ON #QIDSummary.[Quantitation ID] = #TmpQIDSortInfo.QID
		ORDER BY #TmpQIDSortInfo.SortKey
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	Else
	Begin
		SELECT 	[Quantitation ID],
				[Sample Name], [Experiments],
				[Jobs], [MDIDs],
				[Feature (UMC) Count],
				[Feature Count With Hits],
				[Unique PMT Tag Count Matched],
				[Unique Internal Std Count Matched],
				[Comparison PMT Tag Count],
				[Total_Scans_Avg],
				[MD NetAdj NET Min], [MD NetAdj NET Max],
				[Refine Mass Cal PPMShift]
		FROM #QIDSummary INNER JOIN 
			 #TmpQIDSortInfo ON #QIDSummary.[Quantitation ID] = #TmpQIDSortInfo.QID
		ORDER BY #TmpQIDSortInfo.SortKey
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End

Done:
	--
	Return @myError


GO
GRANT EXECUTE ON [dbo].[QRSummary] TO [DMS_SP_User]
GO
