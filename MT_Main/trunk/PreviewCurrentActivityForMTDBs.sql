/****** Object:  StoredProcedure [dbo].[PreviewCurrentActivityForMTDBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure PreviewCurrentActivityForMTDBs
/****************************************************
** 
**	Desc:	Updates T_Current_Activity with the PMT Tag Databases 
**			that need to be updated
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	03/10/2006
**			03/14/2006 mem - Now using column Pause_Length_Minutes
**    
*****************************************************/
(
	@message varchar(255) = '' output
)
As	
	set nocount on
	
	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	declare @MTL_Name varchar(64)
	declare @MTL_State int
	declare @MTL_ID int

	declare @readyForImport float
	declare @demandImport int
	declare @matchCount int
	
	declare @done int

	set @MTL_ID = 0
	set @done = 0
	--
	WHILE @done = 0 and @myError = 0  
	BEGIN --<a>

		-----------------------------------------------------------
		-- get next available entry from peptide database list table
		-----------------------------------------------------------
		--
		SELECT TOP 1
			@MTL_ID = MTL_ID, 
			@MTL_Name = MTL_Name,
			@MTL_State = MTL_State,
			@readyForImport = DATEDIFF(Minute, IsNull(MTL_Last_Import, 0), GETDATE()) / 60.0 - ISNULL(MTL_Import_Holdoff, 24), 
			@demandImport = IsNull(MTL_Demand_Import, 0)
		FROM  T_MT_Database_List
		WHERE    ( (DATEDIFF(Minute, IsNull(MTL_Last_Import, 0), GETDATE()) / 60.0 - ISNULL(MTL_Import_Holdoff, 24) > 0 AND
				    MTL_State IN (2, 5)
				    ) OR
				   (IsNull(MTL_Demand_Import, 0) > 0)
				  ) AND MTL_ID > @MTL_ID
		ORDER BY MTL_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Could not get next entry from MT DB table'
			set @myError = 39
			goto Done
		end
		
		-- We are done if we didn't find any more records
		--
		if @myRowCount = 0
		begin
			set @done = 1
		end
		else
		begin
			if (@demandImport > 0) or (@readyForImport > 0) 
			Begin
				-- Make sure database is present in T_Current_Activity and set Update_State to 1
				--
				Set @matchCount = 0
				SELECT @matchCount = COUNT(*)
				FROM T_Current_Activity
				WHERE Database_ID = @MTL_ID AND Database_Name = @MTL_Name
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				If @matchCount = 0
					INSERT INTO T_Current_Activity (Database_ID, Database_Name, Type, Update_Began, Update_Completed, 
													Pause_Length_Minutes, State, Update_State)
					VALUES (@MTL_ID, @MTL_Name, 'MT', GetDate(), 
							Null, 0, @MTL_State, 1)
				Else
					UPDATE T_Current_Activity
					SET	Database_Name = @MTL_Name, Update_Began = Null, Update_Completed = Null, 
						Pause_Length_Minutes = 0, State = @MTL_State, Comment = '', Update_State = 1
					WHERE Database_ID = @MTL_ID AND Database_Name = @MTL_Name
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
				--
				if @myError <> 0 
				begin
					set @message = 'Could not update current activity table'
					set @myError = 40
					goto Done
				end
			End
		end				
	END --</a>
	
Done:
	return @myError

GO
