-- DBs with this stored procedure:
	-- MT_Human_FY_Lowdose_X362
	-- MT_Mouse_Neurite_Phos_X361
	-- MT_Mouse_Y_pestis_P319


ALTER PROCEDURE dbo.UpdatePMTQSUsingPeptideTable
/****************************************************
** 
**	Desc:	Updates the PMT Quality Score values using
**			tables of user-supplied peptides
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	mem
**	Date:	05/17/2007
**			07/23/2007 - Added parameter @ClearOldPMTQSValues
**    
*****************************************************/
(
	@UserSuppliedTableList varchar(1024) = 'T_User_Peptides_Pass_FDR',
	@PMTQSValues varchar(128)='3',
	@ClearOldPMTQSValues tinyint=1,
	@InfoOnly tinyint = 0,
	@message varchar(255) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	declare @S nvarchar(4000)
	declare @ParamDef nvarchar(256)
	
	declare @CurrentTable varchar(256)
	declare @CurrentNewPMTQS varchar(256)
	
	Declare @OldValuesCleared tinyint
	Declare @continue tinyint
	Declare @StartPositionA int
	Declare @DelimiterPosA int

	Declare @StartPositionB int
	Declare @DelimiterPosB int
	
	Declare @MatchTotal int
	Declare @MatchCount int
	
	-------------------------------------------------------------
	-- Validate the inputs
	-------------------------------------------------------------
	Set @UserSuppliedTableList = LTrim(RTrim(IsNull(@UserSuppliedTableList, '')))
	Set @PMTQSValues = LTrim(RTrim(IsNull(@PMTQSValues, '')))
	Set @ClearOldPMTQSValues = IsNull(@ClearOldPMTQSValues, 1)
	Set @InfoOnly = IsNull(@InfoOnly, 0)
	Set @message = ''
	
	-------------------------------------------------------------
	-- Loop through the values defined in @UserSuppliedTableList and @PMTQSValues
	-------------------------------------------------------------
	--
	Set @StartPositionA = 1
	Set @StartPositionB = 1
	
	if @ClearOldPMTQSValues = 0
		Set @OldValuesCleared = 1
	else
		Set @OldValuesCleared = 0
	
	Set @MatchTotal= 0
	
	Set @continue = 1
	While @continue = 1
	Begin -- <a>
	
		----------------------------------------------------
		-- Parse out the next entry in @UserSuppliedTableList
		----------------------------------------------------
		--
		Set @DelimiterPosA = CharIndex(',', @UserSuppliedTableList, @StartPositionA)
		If @DelimiterPosA = 0
		Begin
			Set @DelimiterPosA = Len(@UserSuppliedTableList) + 1
			Set @continue = 0
		End

		If @DelimiterPosA > @StartPositionA
		Begin -- <b>
			Set @CurrentTable = LTrim(RTrim(SubString(@UserSuppliedTableList, @StartPositionA, @DelimiterPosA - @StartPositionA)))
			
			If Len(@CurrentTable) > 0 
			Begin -- <c>
			
				----------------------------------------------------
				-- Parse out the next entry in @PMTQSValues
				----------------------------------------------------
				--
				Set @DelimiterPosB = CharIndex(',', @PMTQSValues, @StartPositionB)
				If @DelimiterPosB = 0
				Begin
					Set @DelimiterPosB = Len(@PMTQSValues) + 1
					Set @continue = 0
				End
				
				If @DelimiterPosB > @StartPositionB
				Begin -- <d>
					Set @CurrentNewPMTQS = LTrim(RTrim(SubString(@PMTQSValues, @StartPositionB, @DelimiterPosB - @StartPositionB)))
					
					If Len(@CurrentNewPMTQS) > 0 
					Begin -- <e>
					
						----------------------------------------------------
						-- Validate table and PMT QS value found
						-- Preview the update or commit the changes
						----------------------------------------------------
						--

						If @InfoOnly = 0 And @OldValuesCleared = 0
						Begin
							-- Clear the existing PMT Quality Score values
							UPDATE T_Mass_Tags
							Set PMT_Quality_Score = 0
							Where PMT_Quality_Score <> 0
							--
							SELECT @myError = @@error, @myRowCount = @@rowcount
							
							Set @OldValuesCleared = 1
						End

						-- Join peptides in @CurrentTable to T_Peptides and MT_Main
						-- and update the PMT Quality Score values
						Set @S = ''
						If @InfoOnly = 0
						Begin
							Set @S = @S + ' UPDATE T_Mass_Tags'
							Set @S = @S + ' SET PMT_Quality_Score = ' + Convert(varchar(12), @CurrentNewPMTQS)
						End
						Else
						Begin
							Set @S = @S + ' SELECT @matchCount = COUNT(Distinct MT.Mass_Tag_ID)'
						End
						
						Set @S = @S + ' FROM ' + @CurrentTable + ' U'
						Set @S = @S +		' INNER JOIN T_Peptides Pep ON '
						Set @S = @S +			' U.Job = Pep.Analysis_ID'
						Set @S = @S +			' AND U.ScanNum = Pep.Scan_Number'
						Set @S = @S +			' AND U.ScanCount = Pep.Number_Of_Scans'
						Set @S = @S +			' AND U.ChargeState = Pep.Charge_State'
						Set @S = @S +			' AND U.Peptide = Pep.Peptide'
						Set @S = @S +		' INNER JOIN T_Mass_Tags MT ON '
						Set @S = @S +			' Pep.Mass_Tag_ID = MT.Mass_Tag_ID'
						
						If @InfoOnly = 0
						Begin
							Exec sp_executesql @S
							--
							SELECT @myError = @@error, @myRowCount = @@rowcount
							
							Set @matchCount = @myRowCount
						End
						Else
						Begin
							Set @ParamDef = '@matchCount int output'

							exec @myError = sp_executesql @S, @ParamDef, @matchCount = @matchCount output
							
							Set @MatchCount = IsNull(@matchCount, 0)
						End

						If @myError <> 0
						Begin
							Set @message = 'Error with sql: ' + Convert(varchar(19), @myError)
							Goto Done
						End 

						If Len(@message) > 0
							Set @message = @message + '; '
							
						Set @message = @message + 'Set PMT QS to ' + @CurrentNewPMTQS + ' for ' + Convert(varchar(19), @MatchCount) + ' peptides using table ' + @CurrentTable
								
					End -- </e>
				End -- </d>
				
				Set @StartPositionB = @DelimiterPosB + 1
			End -- </c>
		end -- </b>

		Set @StartPositionA = @DelimiterPosA + 1
	
	End -- </a>
	

	If @InfoOnly = 0
		execute PostLogEntry 'Normal', @message, 'UpdatePMTQSUsingPeptideTable'
	Else
	Begin
		
		Select @Message AS Preview_Update_Message
	End


Done:

	If @myError <> 0
	Begin
		execute PostLogEntry 'Error', @message, 'UpdatePMTQSUsingPeptideTable'
	End
	
	return @myError

GO
