SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RefreshSPGlossary]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[RefreshSPGlossary]
GO

CREATE PROCEDURE dbo.RefreshSPGlossary
/****************************************************
**
**	Desc:	Populates T_SP_Glossary with the parameter names
**			and parameter info for the SPs in T_SP_List
**        
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**		@message   -- explanation of any error that occurred
**
**		Auth: mem
**		Date: 11/20/2004
**    
*****************************************************/
	@message varchar(512)='' output
As
	set nocount on

	declare @myError int
	declare @myRowCount int

	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''

	declare @GlossaryEntryCountUpdated int
	declare @SPID int
	declare @continue tinyint

	declare @SPName varchar(128)
	declare @CurrentSPDesc varchar(164)
	
	
	-----------------------------------------------------------
	-- Temporary table to hold the parameters for each SP
	-----------------------------------------------------------
	--
	CREATE TABLE #SPParameterList (
			Parameter_Name sysname, 
			Parameter_Type smallint,
			--Data_Type smallint,
			Data_Type_Name sysname,
			Length int,
			--[Precision] int,
			--[Scale] int,
			Ordinal_Position int
		)

	----------------------------------------------
	-- Loop through T_SP_List, processing each SP listed
	----------------------------------------------
	set @SPID = -1
	set @continue = 1
	set @GlossaryEntryCountUpdated = 0
	
	while @continue > 0 and @myError = 0
	begin
		-- Look up the next available sp
		SELECT	TOP 1 @SPID = SP_ID, @SPName = SP_Name
		FROM	T_SP_List
		WHERE	SP_ID > @SPID
		ORDER BY SP_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 
		begin
			set @message = 'Error while reading next SP from T_SP_List'
			goto done
		end

		if @myRowCount <> 1
			Set @continue = 0
		else
		begin
		
			Set @CurrentSPDesc = @SPName + ' (ID ' + Convert(varchar(9), @SPID) + ')'
			
			----------------------------------------------
			-- Populate #SPParameterList with the parameters for @SPName
			----------------------------------------------
			TRUNCATE TABLE #SPParameterList
			
			INSERT INTO #SPParameterList (
				Parameter_Name, Parameter_Type,
				Data_Type_Name, Length, Ordinal_Position
				)
			SELECT	Parameter_Name, Parameter_Type,
					Data_Type_Name, Length, Ordinal_Position
			FROM GetSPParameters(@SPName)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0 
			begin
				set @message = 'Error while populating #SPParameterList for SP ' + @CurrentSPDesc
				goto done
			end
			
			-- Remove the @ sign at the beginning of the Parameter_Name field in #SPParameterList
			UPDATE #SPParameterList
			SET Parameter_Name = Replace(Parameter_Name, '@', '')
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			
/*
			if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[T_Temp_SPParameterList]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
				drop table [dbo].[T_Temp_SPParameterList]

			SELECT #SPParameterList.* INTO T_Temp_SPParameterList
			FROM #SPParameterList
*/				
			
			----------------------------------------------
			-- Update any existing entries in T_SP_Glossary for @SPID
			----------------------------------------------
			
			-- First update position, field Length, and data type name
			--
			UPDATE T_SP_Glossary
			SET		Ordinal_Position = PL.Ordinal_Position,
					Field_Length = PL.Length,
					Data_Type_Name = PL.Data_Type_Name
			FROM T_SP_Glossary AS SG INNER JOIN #SPParameterList AS PL
					ON SG.Column_Name = PL.Parameter_Name
			WHERE (SG.SP_ID = @SPID) AND 
					(SG.Direction_ID <= 2) AND
					(SG.Ordinal_Position <> PL.Ordinal_Position OR
					 SG.Field_Length <> PL.Length OR
					 SG.Data_Type_Name <> PL.Data_Type_Name
					)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			Set @GlossaryEntryCountUpdated = @GlossaryEntryCountUpdated + @myRowCount
			--
			if @myError <> 0 
			begin
				set @message = 'Error updating position, field length and/or data type name in T_SP_Glossary for SP ' + @CurrentSPDesc
				goto done
			end
			

			-- Second, update direction_id (1 = input, 2 = output)
			--
			UPDATE T_SP_Glossary
			SET		Direction_ID = Parameter_Type
			FROM T_SP_Glossary AS SG INNER JOIN #SPParameterList AS PL
					ON SG.Column_Name = PL.Parameter_Name
			WHERE (SG.SP_ID = @SPID) AND 
					(SG.Direction_ID <= 2) AND
					(SG.Direction_ID <> PL.Parameter_Type)    
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			Set @GlossaryEntryCountUpdated = @GlossaryEntryCountUpdated + @myRowCount
			--
			if @myError <> 0 
			begin
				set @message = 'Error updating Direction_ID in T_SP_Glossary for SP ' + @CurrentSPDesc
				goto done
			end


			-- Third, update any extra entries in T_SP_Glossary for @SPID,
			-- assigning an Ordinal_Position value of -1
			--
			UPDATE T_SP_Glossary
			SET		Ordinal_Position = -1
			FROM T_SP_Glossary AS SG LEFT OUTER JOIN #SPParameterList AS PL
					ON SG.Column_Name = PL.Parameter_Name
			WHERE (SG.SP_ID = @SPID) AND 
					(SG.Direction_ID <= 2) AND
					(PL.Ordinal_Position IS NULL)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			Set @GlossaryEntryCountUpdated = @GlossaryEntryCountUpdated + @myRowCount
			--
			if @myError <> 0 
			begin
				set @message = 'Error marking extra entries in T_SP_Glossary for SP ' + @CurrentSPDesc
				goto done
			end

			----------------------------------------------
			-- Add new (missing) entries to T_SP_Glossary for @SPName
			----------------------------------------------
			--
			INSERT INTO T_SP_Glossary
				(SP_ID, Column_Name, Direction_ID,
					Ordinal_Position, Data_Type_Name, Field_Length)
			SELECT @SPID, PL.Parameter_Name, PL.Parameter_Type, 
				PL.Ordinal_Position, PL.Data_Type_Name, PL.Length
			FROM #SPParameterList AS PL LEFT OUTER JOIN T_SP_Glossary AS SG
					ON PL.Parameter_Name = SG.Column_Name AND SG.SP_ID = @SPID
			WHERE (SG.SP_ID IS NULL)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			Set @GlossaryEntryCountUpdated = @GlossaryEntryCountUpdated + @myRowCount
			--
			if @myError <> 0 
			begin
				set @message = 'Error adding new entries to T_SP_Glossary for SP ' + @CurrentSPDesc
				goto done
			end

		end
	end

	
	-----------------------------------------------
	-- exit the stored procedure
	-----------------------------------------------
	-- 
Done:

	-- Post a log entry if an error exists
	if @myError <> 0
		execute PostLogEntry 'Error', @message, 'RefreshSPGlossary'

	-- Post a log entry if any entries in T_SP_Glossary were updated
	if @GlossaryEntryCountUpdated > 0
	begin
		Set @message = 'Updated ' + Convert(varchar(9), @GlossaryEntryCountUpdated) + ' entries in T_SP_Glossary'
		execute PostLogEntry 'Normal', @message, 'RefreshSPGlossary'
	end
	
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

