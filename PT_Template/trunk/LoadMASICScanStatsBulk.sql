SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[LoadMASICScanStatsBulk]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[LoadMASICScanStatsBulk]
GO


CREATE Procedure dbo.LoadMASICScanStatsBulk
/****************************************************
**
**	Desc: 
**		Load Scan Stats for MASIC job into T_Dataset_Stats_Scans
**		for given analysis job using bulk loading techniques
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	
**
**		Auth: mem
**		Date: 12/12/2004
**			  10/23/2005 mem - Increased size of @ScanStatsFilePath from varchar(255) to varchar(512)
**    
*****************************************************/
	@ScanStatsFilePath varchar(512),
	@Job int,
	@numLoaded int=0 output,
	@message varchar(512)='' output
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	set @numLoaded = 0
	set @message = ''

	declare @jobStr varchar(12)
	set @jobStr = cast(@Job as varchar(12))

	declare @Sql varchar(1024)

	-----------------------------------------------
	-- create temporary table to hold contents of file
	-----------------------------------------------
	--
	CREATE TABLE #T_ScanStats_Import (
		Dataset_ID int NOT NULL ,
		Scan_Number int NOT NULL ,
		Scan_Time real NULL ,
		Scan_Type tinyint NULL ,
		Total_Ion_Intensity float NULL ,
		Base_Peak_Intensity float NULL ,
		Base_Peak_MZ float NULL ,
		Base_Peak_SN_Ratio real NULL 
	)
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Problem creating temporary table #T_ScanStats_Import for job ' + @jobStr
		goto Done
	end
	
	-----------------------------------------------
	-- bulk load contents of scan stats file into temporary table
	-----------------------------------------------
	--
	declare @result int
	declare @c nvarchar(255)

	Set @c = 'BULK INSERT #T_ScanStats_Import FROM ' + '''' + @ScanStatsFilePath + ''''
	exec @result = sp_executesql @c
	--
	if @result <> 0
	begin
		set @message = 'Problem executing bulk insert for job ' + @jobStr
		Set @myError = 50001
		goto Done
	end


	-----------------------------------------------
	-- Delete any existing results for @Job in T_Dataset_Stats_Scans
	-----------------------------------------------
	DELETE FROM T_Dataset_Stats_Scans
	WHERE Job = @Job
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error deleting existing entries in T_Dataset_Stats_Scans for job ' + @jobStr
		goto Done
	end


	-----------------------------------------------
	-- copy contents of temporary table into T_Dataset_Stats_Scans
	-----------------------------------------------
	--
	INSERT INTO T_Dataset_Stats_Scans
	(
		Job,
		Scan_Number,
		Scan_Time,
		Scan_Type,
		Total_Ion_Intensity,
		Base_Peak_Intensity,
		Base_Peak_MZ,
		Base_Peak_SN_Ratio
	)
	SELECT
		@Job,	
		Scan_Number,
		Scan_Time,
		Scan_Type,
		Total_Ion_Intensity,
		Base_Peak_Intensity,
		Base_Peak_MZ,
		Base_Peak_SN_Ratio
	FROM #T_ScanStats_Import
	ORDER BY Scan_Number
	--
	SELECT @myRowCount = @@rowcount, @myError = @@error
	--
	if @myError <> 0
	begin
		set @message = 'Error inserting into T_Dataset_Stats_Scans for job ' + @jobStr
		goto Done
	end

	Set @numLoaded = @myRowCount

Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

