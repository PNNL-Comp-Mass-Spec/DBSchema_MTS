/****** Object:  StoredProcedure [dbo].[QRDetermineSortOrder] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE Procedure QRDetermineSortOrder
/****************************************************	
**  Desc:	Copies QID values from temporary table #TmpQIDValues 
**			 to temporary table #TmpQIDSortInfo, sorting based on @SortMode
**
**			Note: the calling procedure needs to create these two tables:
**
**			CREATE TABLE #TmpQIDValues (
**					UniqueRowID int identity(1,1),
**					QID int NOT NULL)
**
**			CREATE TABLE #TmpQIDSortInfo (
**				SortKey int identity (1,1),
**				QID int NOT NULL)
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	11/28/2006
**			01/24/2008 mem - Added mode 5: Dataset Acq_Time_Start
**
****************************************************/
(
	@SortMode tinyint=2				-- 0=Unsorted, 1=QID, 2=SampleName, 3=Comment, 4=Job (first job if more than one job), 5=Dataset Acq_Time_Start
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0
	
	Declare @MatchFound tinyint
	Set @MatchFound = 0
	
	-------------------------------------------------
	-- Populate #TmpQIDSortInfo based on @SortMode
	-------------------------------------------------	
	--
	If @SortMode = 1
	Begin
		-- Sort by QID
		INSERT INTO #TmpQIDSortInfo (QID)
		SELECT QID
		FROM #TmpQIDValues
		ORDER BY QID
		
		Set @MatchFound = 1
	End

	If @SortMode = 2
	Begin
		-- Sort by SampleName
		INSERT INTO #TmpQIDSortInfo (QID)
		SELECT QID
		FROM #TmpQIDValues QV LEFT OUTER JOIN
			 T_Quantitation_Description QD ON QV.QID = QD.Quantitation_ID
		ORDER BY IsNull(QD.SampleName, Convert(varchar(12), QV.QID))
		
		Set @MatchFound = 1
	End

	If @SortMode = 3
	Begin
		-- Sort by Comment
		INSERT INTO #TmpQIDSortInfo (QID)
		SELECT QID
		FROM #TmpQIDValues QV LEFT OUTER JOIN
			 T_Quantitation_Description QD ON QV.QID = QD.Quantitation_ID
		ORDER BY IsNull(QD.Comment, Convert(varchar(12), QV.QID))
		
		Set @MatchFound = 1
	End

	If @SortMode = 4
	Begin
		-- Sort by Job
		INSERT INTO #TmpQIDSortInfo (QID)
		SELECT QID
		FROM #TmpQIDValues QV LEFT OUTER JOIN
			 (	SELECT QD.Quantitation_ID, MIN(MMD.MD_Reference_Job) AS Job
				FROM T_Quantitation_Description QD INNER JOIN
					T_Quantitation_MDIDs QMD ON QD.Quantitation_ID = QMD.Quantitation_ID INNER JOIN
					T_Match_Making_Description MMD ON QMD.MD_ID = MMD.MD_ID
				GROUP BY QD.Quantitation_ID
				) JobByQID ON QV.QID = JobByQID.Quantitation_ID
		ORDER BY IsNull(JobByQID.Job, QV.QID)
		
		Set @MatchFound = 1
	End

	If @SortMode = 5
	Begin
		-- Sort by Dataset Acq_Time_Start
		INSERT INTO #TmpQIDSortInfo (QID)
		SELECT QID
		FROM #TmpQIDValues QV LEFT OUTER JOIN
			 (	SELECT QD.Quantitation_ID,
					   MIN(ISNULL(FAD.Dataset_Acq_Time_Start, FAD.Dataset_Created_DMS)) AS Dataset_Date
				FROM T_Quantitation_Description QD INNER JOIN 
					 T_Quantitation_MDIDs QMD ON QD.Quantitation_ID = QMD.Quantitation_ID INNER JOIN 
					 T_Match_Making_Description MMD ON QMD.MD_ID = MMD.MD_ID INNER JOIN 
					 T_FTICR_Analysis_Description FAD ON MMD.MD_Reference_Job = FAD.Job
				GROUP BY QD.Quantitation_ID
			) DateByQID ON QV.QID = DateByQID.Quantitation_ID
		ORDER BY IsNull(DateByQID.Dataset_Date, QV.QID)
		
		Set @MatchFound = 1
	End
	
	If @SortMode = 0 OR @MatchFound = 0
	Begin
		-- Sort by the order added to #TmpQIDValues
		INSERT INTO #TmpQIDSortInfo (QID)
		SELECT QID
		FROM #TmpQIDValues
		ORDER BY UniqueRowID
		
		Set @MatchFound = 1
	End

	
Done:	
	Return @myError

GO
GRANT EXECUTE ON [dbo].[QRDetermineSortOrder] TO [DMS_SP_User]
GO
