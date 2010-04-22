/****** Object:  StoredProcedure [dbo].[PreviewCurrentActivityForPeptideDBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure PreviewCurrentActivityForPeptideDBs
/****************************************************
** 
**	Desc:	Updates T_Current_Activity with the Peptide Databases 
**			that need to be updated
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**
**	Auth:	mem
**	Date:	03/10/2006
**			03/14/2006 mem - Now using column Pause_Length_Minutes
**			07/15/2006 mem - Updated list of database states to process to include state 7
**			10/21/2008 mem - Updated to check for and correct database ID conflicts
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

	declare @PDB_Name varchar(64)
	declare @PDB_State int
	declare @PDB_ID int

	declare @readyForImport float
	declare @demandImport int
	declare @matchCount int

	declare @done int

	set @PDB_ID = 0
	set @done = 0
	--
	WHILE @done = 0 and @myError = 0  
	BEGIN --<a>

		-----------------------------------------------------------
		-- get next available entry from peptide database list table
		-----------------------------------------------------------
		--
		SELECT TOP 1
			@PDB_ID = PDB_ID, 
			@PDB_Name = PDB_Name,
			@PDB_State = PDB_State,
			@readyForImport = DATEDIFF(Minute, IsNull(PDB_Last_Import, 0), GETDATE()) / 60.0 - ISNULL(PDB_Import_Holdoff, 24), 
			@demandImport = IsNull(PDB_Demand_Import, 0)
		FROM  T_Peptide_Database_List
		WHERE    ( (DATEDIFF(Minute, IsNull(PDB_Last_Import, 0), GETDATE()) / 60.0 - ISNULL(PDB_Import_Holdoff, 24) > 0 AND
				    PDB_State IN (2, 5, 7)
				    ) OR
				   (IsNull(PDB_Demand_Import, 0) > 0)
				  ) AND PDB_ID > @PDB_ID
		ORDER BY PDB_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Could not get next entry from peptide DB table'
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
				WHERE Database_ID = @PDB_ID AND Database_Name = @PDB_Name
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				If @matchCount = 0
				Begin
					-- Database not present; need to add it
					-- However, first check that no PT DBs exist with the same ID but different name
					DELETE FROM T_Current_Activity
					WHERE Database_ID = @PDB_ID AND Type = 'PT'
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					
					INSERT INTO T_Current_Activity (Database_ID, Database_Name, Type, Update_Began, Update_Completed, 
													Pause_Length_Minutes, State, Update_State)
					VALUES (@PDB_ID, @PDB_Name, 'PT', GetDate(), 
							Null, 0, @PDB_State, 1)
				End
				Else
				Begin
					UPDATE T_Current_Activity
					SET	Database_Name = @PDB_Name, Update_Began = Null, Update_Completed = Null, 
						Pause_Length_Minutes = 0, State = @PDB_State, Comment = '', Update_State = 1
					WHERE Database_ID = @PDB_ID AND Database_Name = @PDB_Name
				End
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
GRANT VIEW DEFINITION ON [dbo].[PreviewCurrentActivityForPeptideDBs] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[PreviewCurrentActivityForPeptideDBs] TO [MTS_DB_Lite] AS [dbo]
GO
