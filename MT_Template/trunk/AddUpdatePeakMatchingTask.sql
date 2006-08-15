/****** Object:  StoredProcedure [dbo].[AddUpdatePeakMatchingTask] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.AddUpdatePeakMatchingTask
/****************************************************
**
**	Desc: Adds a new entry to the peak matching task table
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters: 
**
**	Auth:	grk
**	Date:	5/21/2003
**			07/01/2003 mem
**			07/22/2003 mem
**			09/11/2003 mem
**			01/06/2004 mem - Added support for Minimum_PMT_Quality_Score 
**			09/20/2004 mem - Updated to new MTDB schema
**			02/05/2005 mem - Added parameter @MinimumHighDiscriminantScore
**			06/28/2005 mem - Increased size of @IniFileName to 255 characters
**			07/05/2006 mem - Updated behavior of @SetStateToHolding so that non-zero values result in Processing_State = 5
**      
*****************************************************/
(
	@job int,
	@iniFileName varchar(255),
	@confirmedOnly tinyint = 0,
	@modList varchar(128) = '',
	@MinimumHighNormalizedScore real = 1.5,
	@MinimumHighDiscriminantScore real = .5,
	@MinimumPMTQualityScore real = 0,
	@priority int = 3,
	@taskID int output,
	@mode varchar(12) = 'add', -- or 'update'
	@message varchar(512) output,
	@SetStateToHolding tinyint = 0		-- If non-zero, will set the Processing_State to 5 = Holding; otherwise, sets state at 1
)
As
	set nocount on

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''
		
	declare @taskStr varchar(12)
	set @taskStr = CAST(@taskID as varchar(12))

	declare @hit int,
			@ProcessingState tinyint
	
	---------------------------------------------------
	-- If updating, make sure entry is already in T_Peak_Matching_Tasks
	---------------------------------------------------

	If @mode = 'update'
	Begin
		set @hit = 0
		--
		SELECT @hit = Count(*)
		FROM T_Peak_Matching_Task
		WHERE (Task_ID = @taskID)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error checking for existing task "' + @taskStr + '"'
			RAISERROR (@message, 10, 1)
			return 51007
		end

		-- cannot update a non-existent entry
		--
		if @hit = 0 and @mode = 'update'
		begin
			set @message = 'Cannot update: Requested task "' + @taskStr + '" is not in database '
			RAISERROR (@message, 10, 1)
			return 51004
		end
	End

	
	---------------------------------------------------
	-- validate that job exists in database
	---------------------------------------------------
	
	set @hit = 0
	--
	SELECT @hit = COUNT(*)
	FROM T_FTICR_Analysis_Description
	WHERE (Job = @job)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Could not cross check job'
		RAISERROR (@message, 10, 1)
		return 51009
	end
	
	if @hit = 0
	begin
		set @message = 'Job ' + cast(@job as varchar(12)) + ' could not be found in table' 
		RAISERROR (@message, 10, 1)
		return 51010
	end
	
	If IsNull(@SetStateToHolding, 0) <> 0
		Set @ProcessingState = 5
	Else
		Set @ProcessingState = 1
		
	---------------------------------------------------
	-- action for add mode
	---------------------------------------------------
	
	if @Mode = 'add'
	begin

		set @taskID = 0

		INSERT INTO T_Peak_Matching_Task
		(
			Output_Folder_Name, 
			Job, 
			Confirmed_Only, 
			Mod_List,
			Minimum_High_Normalized_Score,
			Minimum_High_Discriminant_Score,
			Minimum_PMT_Quality_Score,
			Ini_File_Name,
			PM_Created,
			Processing_State,
			Priority
		)
		VALUES
		(
			'',
			@job,
			@confirmedOnly,
			@modList,
			@MinimumHighNormalizedScore,
			@MinimumHighDiscriminantScore,
			@MinimumPMTQualityScore,
			@iniFileName,
			GetDate(),
			@ProcessingState,
			@priority
		)	
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount, @taskID = @@identity
		--
		if @myError <> 0
		begin
			set @message = 'Insert operation failed for job ' + cast(@job as varchar(12))
			RAISERROR (@message, 10, 1)
			return 51007
		end
		

	end -- add mode

	---------------------------------------------------
	-- action for update mode
	---------------------------------------------------
	--
	if @Mode = 'update' 
	begin
		set @myError = 0
		--
		UPDATE T_Peak_Matching_Task
		SET 
			Job = @job, 
			Confirmed_Only = @confirmedOnly, 
			Mod_List = @modList, 
			Minimum_High_Normalized_Score = @MinimumHighNormalizedScore,
			Minimum_PMT_Quality_Score = @MinimumPMTQualityScore,
			Ini_File_Name = @iniFileName, 
			Processing_State = @ProcessingState,
			Priority = @priority
		WHERE (Task_ID = @taskID)
		--

		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 or @myRowCount <> 1
		begin
			set @message = 'Update operation failed'
			RAISERROR (@message, 10, 1)
			return 51004
		end
	end -- update mode

	return 0


GO
GRANT EXECUTE ON [dbo].[AddUpdatePeakMatchingTask] TO [DMS_SP_User]
GO
