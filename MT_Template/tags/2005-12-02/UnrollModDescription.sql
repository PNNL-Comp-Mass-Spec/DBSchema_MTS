SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UnrollModDescription]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UnrollModDescription]
GO


create PROCEDURE dbo.UnrollModDescription
/****************************************************
** 
**		Desc:
**      Unrolls mod description into individual mod descriptors
**      and enters them into temporary table #TModDescriptors'
**      that needs to have been created by caller
** 
**		Return values: 0: success, otherwise, error code
**						If @modDescription is not of the form ModName:0
**						then the error code is 90000
** 
**		Parameters:
**
**		Date: 
**        8/22/2004 grk - Initial version
**		 10/18/2004 mem - Added error code 90000 for cases where @modDescription is invalid
**    
*****************************************************/
	@Mass_Tag_ID int,
	@modDescription varchar(2048),
	@message varchar(256) output
AS
	set nocount on
	
	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''
	
	if @modDescription = ''
		goto Done

	---------------------------------------------------
	-- 
	---------------------------------------------------
	
	declare @comma char(1)
	set @comma = ','
	declare @colon char(1)
	set @colon = ':'

	declare @done int
	declare @count int

	declare @tPos int
	set @tPos = 1
	declare @tFld varchar(128)

	declare @nPos int
	set @nPos = 1
	declare @nFld varchar(128)
	declare @result int
	
	declare @massCorrectionTag char(8)
	declare @modPos int

	-- process list 
	--
	set @count = 0
	set @done = 0

	while @done = 0 and @myError = 0
	begin
		set @count = @count + 1

		-- process the next field from the member list
		--
		set @tFld = ''
		execute @done = NextField @modDescription, @comma, @tPos output, @tFld output

		if @tFld <> ''
		begin
			-- split the field
			set @nPos = 1
			set @nFld = ''
			set @massCorrectionTag = 0
			set @modPos = 0
			--
			execute @result = NextField @tFld, @colon, @nPos output, @nFld output
			set @massCorrectionTag = @nFld 
			--
			If @nPos <= Len(@tFld)
			Begin
				execute @result = NextField @tFld, @colon, @nPos output, @nFld output
				If IsNumeric(@nFld) = 1
				Begin
					set @modPos = cast(@nFld as int)
					
					-- insert mod descriptor into temporary table
					--
					Insert into #TModDescriptors 
						(Mass_Tag_ID, Mass_Correction_Tag, [Position])
					Values 
						(@Mass_Tag_ID, @massCorrectionTag, @modPos)
					--
					SELECT @myError = @@error, @myRowCount = @@rowcount
					--
					if @myError <> 0
					begin
						set @message = 'Error trying to insert mod set member'
						goto Done
					end
				End
				Else
				Begin
					Set @myError = 90000	-- Note that error code 90000 is used by CalculateMonoisotopicMass
					goto Done
				End
			End
			Else
			Begin
				Set @myError = 90000	-- Note that error code 90000 is used by CalculateMonoisotopicMass
			End
		end
	end

Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

