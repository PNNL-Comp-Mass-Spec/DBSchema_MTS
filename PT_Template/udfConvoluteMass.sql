/****** Object:  UserDefinedFunction [dbo].[udfConvoluteMass] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION dbo.udfConvoluteMass
/****************************************************	
**	Converts @MassMZ to the MZ that would appear at the given @DesiredCharge
**	If @CurrentCharge = 0, then assumes MassMZ is the neutral, monoisotopic mass
**	To return the neutral mass, set @DesiredCharge to 0
**
**	Auth:	mem
**	Date:	01/28/2013
**  
****************************************************/
(
	@MassMZ float, 
	@CurrentCharge int, 
	@DesiredCharge int = 1
)
RETURNS float
AS
BEGIN

	-- Note that this is the mass of hydrogen minus the mass of one electron
	Declare @MassProton float = 1.00727649
	
	Declare @NewMZ float


    If @CurrentCharge = @DesiredCharge
        Set @NewMZ = @MassMZ
    Else
    Begin
	    If @CurrentCharge = 1
	        Set @NewMZ = @MassMZ
	        
	    If @CurrentCharge > 1
	    Begin
	        -- Convert @MassMZ to M+H
	        Set @NewMZ = (@MassMZ * @CurrentCharge) - @MassProton * (@CurrentCharge - 1)
	    End
	    
	    
	    If @CurrentCharge = 0
	    Begin
	        -- Convert @MassMZ (which is neutral) to M+H and store in @NewMZ
	        Set @NewMZ = @MassMZ + @MassProton
	    End
	    
	    If @CurrentCharge < 0
	    Begin
	        -- Negative charges are not supported; return 0
	        Return 0
	    End

	    If @DesiredCharge > 1
	        Set @NewMZ = (@NewMZ + @MassProton * (@DesiredCharge - 1)) / @DesiredCharge
	    
		If @DesiredCharge = 1
		Begin
	        -- Return M+H, which is currently stored in @NewMZ
	        Set @NewMZ = @NewMZ
		End
		
	    If @DesiredCharge = 0
	    Begin
	        -- Return the neutral mass
	        Set @NewMZ = @NewMZ - @MassProton
	    End
	    
	    If @DesiredCharge < 0
	    Begin
	        -- Negative charges are not supported; return 0
	        Return 0
	    End
	    
	End
    

    Return @NewMZ


END

GO
