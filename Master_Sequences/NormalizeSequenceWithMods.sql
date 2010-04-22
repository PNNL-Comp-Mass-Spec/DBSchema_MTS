/****** Object:  StoredProcedure [dbo].[NormalizeSequenceWithMods] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.NormalizeSequenceWithMods
/****************************************************
** 
**	Desc:	Normalize peptide sequence (remove prefix
**			and suffix and modification notations),
**			and generate modification description
**
**	Return values: 0: success, otherwise, error code
** 
**	Parameters:
**		  @rawSequence		  raw peptide sequence from analysis
**
**	Auth:	grk
**			08/20/2004 grk - Initial version
**			08/26/2004 grk - position value of terminus mod descriptor changed to negative integer
**			09/09/2004 mem - Updated method of storing non-positional tag in @modDescription
**			02/24/2005 mem - Switched from using the ASCII() function to using a LIKE clause to test for the current character being a letter
**			02/26/2005 mem - Improved execution speed by separating out terminus checks from mod symbol checks
**			04/23/2005 mem - Added checking for clean sequences containing invalid characters (!@#$%&*<>.)
**			06/26/2006 mem - No longer using negative integers for the positional value of terminus mods; instead, now using 1 for N-terminal mods and Len(Clean_Sequence) for C-terminal mods; however, Isotopic mods still have a position of 0
**    
*****************************************************/
(
	@rawSequence varchar(900) = '-.abc*defghij#klmnopqrst@uvwxyz.r',
	@PM_TargetSymbolList varchar(128) = '@,#,*,b,[,>,',
	@PM_MassCorrectionTagList varchar(512) = 'IodoAcet,OxDy_Met,OxDy16_M,IodoAcet,ProTermN,PepTermC,',
	@NP_MassCorrectionTagList varchar(512) = 'Iso_N15 ,Sam     ,',
	@cleanSequence varchar(1024) output,
	@modDescription varchar(2048) output,
	@modCount int output,
	@message varchar(256) output
)
As
	set nocount on
	
	declare @myError int
	set @myError = 0
	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''

	set @modCount = 0
	set @cleanSequence = ''
	set @modDescription = ''
	
	declare @seqPos int
	declare @ln int
	declare @ch char(1)
	
	declare @tempSequence varchar(900)

	declare @globalSymbolSize int -- how big is mod symbol
	set @globalSymbolSize = 8

	declare @symIndx int
	declare @NPTag varchar(8)

	-----------------------------------------------------------
	-- clean off terminii from raw sequence
	-----------------------------------------------------------
	
	-- remove peptide prefix and suffix
	--
	set @ln = len(@rawSequence)
	set @tempSequence = left(right(@rawSequence, @ln - 2), @ln-4)

	-----------------------------------------------------------
	-- incorporate any non positional modifications into description
	-----------------------------------------------------------

	if @NP_MassCorrectionTagList <> ''
	begin
		-- count number of mods in non positional MCF tag list
		--
		set @seqPos = 1
		set @ln = len(@NP_MassCorrectionTagList)
		while @seqPos <= @ln
		begin
			set @seqPos = CharIndex(',', @NP_MassCorrectionTagList, @seqPos+1)
			
			if @seqPos > 1
			begin
				set @modCount = @modCount + 1
				
				-- convert mod list to mod descripton by adding zero position
				-- and add it to description list; must add 1 to @globalSymbolSize
				-- since @NP_MassCorrectionTagList still contains commas
				--
				set @symIndx = ((@modCount-1) * (@globalSymbolSize+1)) + 1
				set @NPTag = rtrim(SUBSTRING(@NP_MassCorrectionTagList, @symIndx, @globalSymbolSize))
				
				set @modDescription = @modDescription + @NPTag + ':0,'
			end
			else
				Set @seqPos = @ln + 1
		end
		
	end

	-----------------------------------------------------------
	-- Check whether to look for positional modifications
	-----------------------------------------------------------
	--
	-- if no modication targets, we are done
	--
	if @PM_TargetSymbolList = '' 
	begin
		-- Possibly remove the trailing comma
		set @ln = len(@modDescription)
		if @ln > 1
			set @modDescription = left(@modDescription, @ln-1)

		set @cleanSequence = @tempSequence
		goto Done
	end

	-----------------------------------------------------------
	-- Handle positional modifications, including terminus mods
	-- Note that terminus mods indicated by <, >, [, or ] are
	--  always treated as static mods
	-- Dynamic terminus mods have a local symbol associated with them
	--  and should appear in the sequence like this:
	-- '-.M!BCDEFGHIJK.F'  or  'R.M!BCDEFGHIJK.F'  or  'R.MBCDEFGHIJK!.F'
	-----------------------------------------------------------
	
	declare @targetIdx int
	declare @MCFTag varchar(8)
	declare @modPos int
	
	declare @IsModSymbol tinyint

	declare @maxModCount int
	set @maxModCount = 2048 / (@globalSymbolSize + 5)-1

	-- get rid of any delimiters in the positional 
	-- mod target and MCF tag lists
	--
	set @PM_TargetSymbolList = replace(@PM_TargetSymbolList, ',', '')
	set @PM_MassCorrectionTagList = replace(@PM_MassCorrectionTagList, ',', '')


	declare @terminusChecks varchar(8)
	
	If @PM_TargetSymbolList LIKE '%]%' OR @PM_TargetSymbolList LIKE '%[<>[]%'
	Begin
		-----------------------------------------------------------
		-- Handle terminus mods
		-----------------------------------------------------------

		-- N terminus
		-- if N terminus of peptide is also N terminus of protein
		-- and if protein terminus check is to be performed, then
		-- use protein N terminus target, otherwise use peptide N terminus target
		--
		if left(@rawSequence, 1) = '-'  AND (charindex('[', @PM_TargetSymbolList) > 0)
			set @terminusChecks = '['
		else
			set @terminusChecks = '<'
		
		-- treat C terminus the same way
		--
		if right(@rawSequence, 1) = '-'  AND (charindex(']', @PM_TargetSymbolList) > 0)
			set @terminusChecks = @terminusChecks + ']'
		else
			set @terminusChecks = @terminusChecks + '>'
		
		-----------------------------------------------------------
		-- Check for N terminus mods
		-----------------------------------------------------------
		-- Position of N-terminal mods is 1
		set @modPos = 1

		set @ch = SUBSTRING(@terminusChecks, 1, 1)

		-- is the given terminus (in @ch) a modification target?
		set @targetIdx = charindex(@ch, @PM_TargetSymbolList)
		if @targetIdx > 0
		begin -- Yes
			-- increment mod count
			set @modCount = @modCount + 1
			
			-- add mod descriptor to mod description
			--
			-- calculate index of MCF tag
			set @symIndx = ((@targetIdx - 1) * @globalSymbolSize) + 1
				
			-- get MCF tag from index
			set @MCFTag = rtrim(SUBSTRING(@PM_MassCorrectionTagList, @symIndx, @globalSymbolSize)) 
			
			-- build mod descriptor from mass correction tag and mod position 
			-- and add it to mod description
			--
			set @modDescription = @modDescription + @MCFTag + ':' + cast(@modPos as varchar(12)) + ',' 
		end
	End
		
	-----------------------------------------------------------
	-- parse raw sequence, 
	-- build clean sequence, 
	-- find modifications  
	-- build mod descriptors and add to the mod descripton
	-----------------------------------------------------------
	--
	set @modPos = 0
	set @seqPos = 1
	set @ln = len(@tempSequence)

	while @seqPos <= @ln AND @myError = 0
	begin
		-- get next char in raw sequence
		--
		set @ch = SUBSTRING(@tempSequence, @seqPos, 1)  
		
		-- if char is an amino acid, then add to clean sequence
		--
		if @ch LIKE '[A-Z]'
		begin
			set @cleanSequence = @cleanSequence + @ch
			set @IsModSymbol = 0
		end
		else
			set @IsModSymbol = 1
		
		-- is char a modification target?
		--
		set @targetIdx = charindex(@ch, @PM_TargetSymbolList)
		if @targetIdx = 0
		begin
			-- If @ch is a modification symbol and if we didn't 
			-- find it in @PM_TargetSymbolList, then raise an error
			if @IsModSymbol = 1
			begin
				set @message = 'Unknown modification symbol ' + @ch + ' for raw sequence ' + @rawSequence
				set @cleanSequence = ''
				set @myError = 1
			end		
		end
		else
			begin -- Yes
				-- increment mod count
				set @modCount = @modCount + 1
				
				-- get position of modification in clean sequence
				set @modPos = len(@cleanSequence)
				
				-- add mod descriptor to mod description
				if @modCount > @maxModCount -- make sure mod description does not exceed max size
				begin
					set @message = 'Modification description string is too big'
					set @cleanSequence = ''
					set @myError = 2
				end
				else
				begin 
					-- calculate index of MCF tag
					set @symIndx = ((@targetIdx -1) * @globalSymbolSize) + 1
					 
					-- get MCF tag from index
					set @MCFTag = rtrim(SUBSTRING(@PM_MassCorrectionTagList, @symIndx, @globalSymbolSize)) 
					
					-- build mod descriptor from mass correction tag and mod position 
					-- and add it to mod description
					--
					set @modDescription = @modDescription + @MCFTag + ':' + cast(@modPos as varchar(12)) + ',' 
				end
			end -- Yes
		set @seqPos = @seqPos + 1
	end

	If @PM_TargetSymbolList LIKE '%]%' OR @PM_TargetSymbolList LIKE '%>%'
	Begin
		-----------------------------------------------------------
		-- Check for C terminus mods
		-----------------------------------------------------------
		-- Position of C-terminal mods is Len(@cleanSequence)
		set @modPos = Len(@cleanSequence)

		set @ch = SUBSTRING(@terminusChecks, 2, 1)

		-- is the given terminus (in @ch) a modification target?
		set @targetIdx = charindex(@ch, @PM_TargetSymbolList)
		if @targetIdx > 0
		begin -- Yes
			-- increment mod count
			set @modCount = @modCount + 1
			
			-- add mod descriptor to mod description
			--
			-- calculate index of MCF tag
			set @symIndx = ((@targetIdx - 1) * @globalSymbolSize) + 1
				
			-- get MCF tag from index
			set @MCFTag = rtrim(SUBSTRING(@PM_MassCorrectionTagList, @symIndx, @globalSymbolSize)) 
			
			-- build mod descriptor from mass correction tag and mod position 
			-- and add it to mod description
			--
			set @modDescription = @modDescription + @MCFTag + ':' + cast(@modPos as varchar(12)) + ',' 
		end
	End
	
	-----------------------------------------------------------
	-- remove trailing comma from modification description string
	-----------------------------------------------------------
	--
	set @ln = len(@modDescription)
	if @ln > 1
		set @modDescription = left(@modDescription, @ln-1)
	
Done:
	If @myError = 0
	Begin
		If @CleanSequence LIKE '%[!@#$%&*<>.]%'
		Begin
			set @message = 'Clean sequence contains an invalid character: ' + @CleanSequence
			set @cleanSequence = ''
			set @myError = 3
		End
	End
	
	return @myError

GO
GRANT VIEW DEFINITION ON [dbo].[NormalizeSequenceWithMods] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NormalizeSequenceWithMods] TO [MTS_DB_Lite] AS [dbo]
GO
