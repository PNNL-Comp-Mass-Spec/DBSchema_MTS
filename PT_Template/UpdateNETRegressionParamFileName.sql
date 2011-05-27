/****** Object:  StoredProcedure [dbo].[UpdateNETRegressionParamFileName] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdateNETRegressionParamFileName
/****************************************************
**
**	Desc:	Examines Peptide_Hit jobs in T_Analysis_Description whose state is between @ProcessStateMin and @ProcessStateMax
**			Updates the NET regression param file name for any that match settings in T_Process_Config
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	mem
**	Date:	10/12/2010 mem - Initial Version
**    
*****************************************************/
(
	@ProcessStateMin int = 10,
	@ProcessStateMax int = 39,
	@message varchar(512) = '' output,
	@infoOnly tinyint = 0,
	@previewSql tinyint = 0
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @MatchCount int
	Declare @JobCount int
	Declare @JobMin int
	Declare @JobMax int
	
	Declare @Iteration int
	Declare @ConfigName varchar(128)
	
	Declare @SqlFrom nvarchar(512)
	Declare @Sql nvarchar(1024)
	Declare @JoinClause varchar(128)
	
	Declare @SqlParams nvarchar(512)
	
	-------------------------------------------------------
	-- Validate the inputs
	-------------------------------------------------------
	
	set @ProcessStateMin = IsNull(@ProcessStateMin, 10)
	set @ProcessStateMax = IsNull(@ProcessStateMax, 39)
	
	Set @message = ''
	Set @infoOnly = IsNull(@infoOnly, 0)
	Set @previewSql = IsNull(@previewSql, 0)
	
	-------------------------------------------------------
	-- See if any candidate jobs exist
	-------------------------------------------------------
	
	Set @JobCount = 0
	
	SELECT @JobCount = COUNT(*)
	FROM T_Analysis_Description TAD
	WHERE TAD.ResultType LIKE '%Peptide_Hit' AND
	      TAD.Process_State >= @ProcessStateMin AND
	      TAD.Process_State <= @ProcessStateMax
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	
	If @JobCount = 0	
		Set @message = 'No peptide_hit jobs found with process state between ' + Convert(varchar(12), @ProcessStateMin) + ' and ' + Convert(varchar(12), @ProcessStateMax)
	Else
	Begin -- <a>

		CREATE TABLE #TmpConfigDefs (
			Value1 varchar(512) NOT NULL,
			Value2 varchar(512) NOT NULL,
		)

		Set @Iteration = 1
		While @Iteration <= 2
		Begin -- <b>

			TRUNCATE TABLE #TmpConfigDefs
			
			If @Iteration = 1
			Begin
				Set @ConfigName = 'NET_Regression_Param_File_Name_by_Campaign'				
				Set @JoinClause = 'TAD.Campaign = #TmpConfigDefs.Value1'
			End
			
			If @Iteration = 2
			Begin
				Set @ConfigName = 'NET_Regression_Param_File_Name_by_Sample_Label'
				Set @JoinClause = 'TAD.Labelling = #TmpConfigDefs.Value1'
			End
			
			If @infoOnly <> 0 or @previewSql <> 0
				print 'ConfigName: ' + @ConfigName
			
			exec ParseConfigListDualKey @ConfigName, @MatchCount output
			
			if @infoOnly <> 0
				SELECT @ConfigName AS Config_Name, *
				FROM #TmpConfigDefs
				
			If @MatchCount > 0
			Begin -- <c>
			
				Set @SqlFrom = ''
				Set @SqlFrom = @SqlFrom + ' FROM T_Analysis_Description TAD'
				Set @SqlFrom = @SqlFrom +        ' INNER JOIN #TmpConfigDefs ON ' + @JoinClause
				Set @SqlFrom = @SqlFrom + ' WHERE TAD.ResultType LIKE ''%Peptide_Hit'' AND '
				Set @SqlFrom = @SqlFrom +       ' TAD.Process_State >= ' + Convert(varchar(12), @ProcessStateMin) + ' AND '
				Set @SqlFrom = @SqlFrom +       ' TAD.Process_State <= ' + Convert(varchar(12), @ProcessStateMax) + ' AND '
				Set @SqlFrom = @SqlFrom +       ' IsNull(Regression_Param_File, '''') <> #TmpConfigDefs.Value2'
						
				If @infoOnly <> 0
				Begin -- <d1>
					Set @Sql = ''
					Set @Sql = @Sql + ' SELECT TAD.Job, TAD.Process_State, TAD.Campaign, TAD.Labelling, '
					Set @Sql = @Sql + ' Regression_Param_File, #TmpConfigDefs.Value2 AS Regression_Param_File_New '
					Set @Sql = @Sql + @SqlFrom
					
					If @previewSql <> 0
						Print @Sql
					Else
						Exec (@Sql)
				End -- </d1>
				Else
				Begin -- <d2>

					Set @Sql = ''
					Set @Sql = @Sql + ' SELECT @JobMin = MIN(Job), @JobMax = MAX(Job) '
					Set @Sql = @Sql + @SqlFrom
					
					Set @SqlParams =  '@JobMin int output, @JobMax int output'
					
					If @previewSql <> 0
						Print @Sql
					Else
						Exec sp_executesql @Sql, @SqlParams, @JobMin = @JobMin output, @JobMax = @JobMax output
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
		       
		       
					Set @Sql = ''
					Set @Sql = @Sql + ' UPDATE T_Analysis_Description '
					Set @Sql = @Sql + ' SET Regression_Param_File = #TmpConfigDefs.Value2 '
					Set @Sql = @Sql + @SqlFrom
					
					If @previewSql <> 0
						Print @Sql
					Else
						Exec (@Sql)
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
					If @myRowCount > 0 And @previewSql = 0
					Begin -- <e>
						Set @message = 'Auto-defined Regression_Param_File in T_Analysis_Description'
						
						If @JobMin = @JobMax
							Set @message = @message + ' for job ' + Convert(varchar(12), @JobMin)
						Else
							Set @message = @message + ' for jobs ' + Convert(varchar(12), @JobMin) + ' to ' + Convert(varchar(12), @JobMax)
						
						Exec PostLogEntry 'Normal', @message, 'UpdateNETRegressionParamFileName'

					End  -- </e>
					
				End  -- </d2>
				
			End -- </c>
			
			Set @Iteration = @Iteration + 1 
		End -- </b>
		
	End -- </a>

	
Done:
	Return @myError


GO
