/****** Object:  StoredProcedure [dbo].[UpdateCachedAnalysisTasksForThisDB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdateCachedAnalysisTasksForThisDB
/****************************************************
**
**	Desc:	Updates table T_Analysis_Task_Candidate_DBs in the Prism_RPT database
**			with the analysis tasks available for VIPER and MultiAlign in this DB
**
**	Auth:	mem
**	Date:	02/18/2008
**
*****************************************************/
(
	@ToolIDFilter int = 0,					-- If defined, then only updates this tool
	@message varchar(512) = '' output
)
As
	set nocount on

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''

	Declare @ServerName varchar(128)
	Declare @DBName varchar(128)

	Set @ServerName = @@ServerName
	Set @DBName = DB_Name()

	-- Call UpdateCachedAnalysisTasks in the Prism_RPT database on Pogo
	exec Pogo.Prism_RPT.dbo.UpdateCachedAnalysisTasks 
				@ServerNameFilter=@ServerName, 
				@DBNameFilter=@DBName, 
				@ToolIDFilter=@ToolIDFilter, 
				@ForceUpdate=1,
				@message=@message output

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:
	Return @myError


GO
