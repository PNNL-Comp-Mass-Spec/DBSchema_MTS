/****** Object:  StoredProcedure [dbo].[PopulateMissedCleavageColumn] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.PopulateMissedCleavageColumn
/****************************************************
** 
**	Desc: 
**		Fills in the column (Missed_Cleavage_Count) in 
**			Mass_Tag_to_Protein_Map
**
**		Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	08/09/2006
**    
*****************************************************/
(
	@count int = 0 output,						--number of rows updated
	@message varchar(255) = '' output,
	@AbortOnError int = 0,						--if 0, then go to next Mass_Tag_ID on error; otherwise, return error code on error
	@RecomputeAll tinyint = 0,					-- When 1, recomputes masses for all mass tags; when 0, only computes if the peptide name or peptide cleavage state is null
	@logLevel tinyint = 1
)	
AS
	SET NOCOUNT ON

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @message = ''
	set @count = 0
	
	declare @done int
	declare @LastUniqueRowID int
	declare @UpdateEnabled tinyint
	
	--results extracted for each row are stored in these
	declare @peptide varchar(850)
	declare @Mass_Tag_ID int

	set @peptide = ''
	set @Mass_Tag_ID = -1
	
	declare @lastProgressUpdate datetime
	Set @lastProgressUpdate = GetDate()
		
	--variables for storing calculated results to be output to T_Mass_Tag_to_Protein_Map
	declare @missedCleavageCount int
	
	---------------------------------------------------
	-- Creation of temporary table to pull data from
	---------------------------------------------------
	
	CREATE TABLE #TMPTags (
		[Mass_Tag_ID]	int NOT NULL ,
		[Peptide] varchar (850) NOT NULL,
		[Unique_Row_ID] int IDENTITY (1, 1) NOT NULL
	)

	CREATE UNIQUE CLUSTERED INDEX #IX_TempTable_TMPTags ON #TMPTags (Unique_Row_ID)

	---------------------------------------------------
	-- copy data to temp table
	---------------------------------------------------
	
	If @RecomputeAll = 0
	  Begin
		INSERT	#TMPTags (Mass_Tag_ID, Peptide)
		SELECT	DISTINCT MT.Mass_Tag_ID,
				MT.Peptide
		FROM	T_Mass_Tag_to_Protein_Map AS MTPM INNER JOIN T_Mass_Tags AS MT ON 
				MTPM.Mass_Tag_ID = MT.Mass_Tag_ID
		WHERE	Missed_Cleavage_Count IS NULL
		ORDER BY MT.Mass_Tag_ID
	  End
	Else
	  Begin
		INSERT	#TMPTags (Mass_Tag_ID, Peptide)
		SELECT	DISTINCT MT.Mass_Tag_ID,
				MT.Peptide
		FROM	T_Mass_Tag_to_Protein_Map AS MTPM INNER JOIN T_Mass_Tags AS MT ON 
				MTPM.Mass_Tag_ID = MT.Mass_Tag_ID
		ORDER BY MT.Mass_Tag_ID
	  End
	
	
	-- check for errors
	SELECT @myError = @@error, @myRowCount = @@rowcount
	if @myError <> 0 
	begin
		set @message = 'Error populating temporary table'
		goto done
	end
	
	if not(@myRowCount > 0)
	begin
		set @message = 'No data found to process'
		goto done
	end
	
	
	----------------------------------------------
	-- Loop through each row in the temporary table,
	-- calculating Missed_Cleavage_Count
	----------------------------------------------
	Set @done = @myRowCount
	Set @LastUniqueRowID = 0
	
	While @done > 0
	Begin -- <a>
		-- Select data about one Mass_Tag_ID from the temporary table
  		SELECT TOP 1 
  			@LastUniqueRowID = Unique_Row_ID,
			@peptide = Peptide, 
			@Mass_Tag_ID = Mass_Tag_ID
		FROM #TMPTags
		WHERE Unique_Row_ID > @LastUniqueRowID
		ORDER BY Unique_Row_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		set @done = @myRowCount
		if @myError <> 0 
		begin
			set @message = 'Error while reading data from temporary table #TMPTags'
			goto done
		end
		
		If @done = 0
			Set @message = ''
		Else
		Begin -- <b>	
			------------------------------------------------
			-- Compute the number of missed cleavages
			------------------------------------------------

			exec @missedCleavageCount = CountMissedCleavagePoints @peptide
				
			-----------------------------------
			-- Store the computed value
			-----------------------------------
			UPDATE T_Mass_Tag_to_Protein_Map
			SET Missed_Cleavage_Count = @missedCleavageCount
			WHERE Mass_Tag_ID = @Mass_Tag_ID
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			--
			if @myError <> 0 OR @myRowCount < 1
			begin
				set @message = 'Row missing (not updated) for Mass_Tag_ID = ' + Convert(varchar(12), @Mass_Tag_ID)
				set @myError = 75002
				if @AbortOnError <> 0
					goto done
			end
				
			set @count = @count + 1

			if @logLevel >= 1
			Begin -- <c>
				if @count % 1000 = 0 
				Begin -- <d>
					if @count % 100000 = 0 Or DateDiff(second, @lastProgressUpdate, GetDate()) >= 300
					Begin
						set @message = '...Processing: ' + convert(varchar(11), @count)
						execute PostLogEntry 'Progress', @message, 'PopulateMissedCleavageColumn'
						set @message = ''
						set @lastProgressUpdate = GetDate()
					End

					-- Validate that updating is enabled, abort if not enabled
					exec VerifyUpdateEnabled @CallingFunctionDescription = 'PopulateMissedCleavageColumn', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
					If @UpdateEnabled = 0
						Goto Done
				End -- </d>
			End -- </c>	
			
			set @myError = 0
		End -- </b>

	End -- </a>


	--------------------------------------------------
	-- Exit
	---------------------------------------------------
Done:
	return @myError


GO
