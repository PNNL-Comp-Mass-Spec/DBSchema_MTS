/****** Object:  Table [dbo].[T_Peptide_Prophet_DB_Parameters] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peptide_Prophet_DB_Parameters](
	[Charge_State] [smallint] NOT NULL,
	[Tryptic_State] [smallint] NOT NULL,
	[Gamma_Alpha] [real] NULL,
	[Gamma_Alpha_Min] [real] NULL,
	[Gamma_Alpha_Max] [real] NULL,
	[Gamma_Beta] [real] NULL,
	[Gamma_Gamma] [real] NULL,
	[Normal_Mu] [real] NULL,
	[Normal_Sigma] [real] NULL,
	[Mixing_Prob] [real] NULL,
	[MT_Count_Used] [int] NULL,
	[Last_Affected] [datetime] NULL,
	[Entered_By] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Peptide_Prophet_DB_Parameters] PRIMARY KEY CLUSTERED 
(
	[Charge_State] ASC,
	[Tryptic_State] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Peptide_Prophet_DB_Parameters] ADD  CONSTRAINT [DF_T_Peptide_Prophet_DB_Parameters_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
ALTER TABLE [dbo].[T_Peptide_Prophet_DB_Parameters] ADD  CONSTRAINT [DF_T_Peptide_Prophet_DB_Parameters_Entered_By]  DEFAULT (suser_sname()) FOR [Entered_By]
GO
/****** Object:  Trigger [dbo].[trig_u_T_Peptide_Prophet_DB_Parameters] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

create TRIGGER trig_u_T_Peptide_Prophet_DB_Parameters ON T_Peptide_Prophet_DB_Parameters 
FOR UPDATE
AS
/****************************************************
**
**	Desc: 
**		Updates the Last_Affected and Entered_By fields if any of the other fields are changed
**
**	Auth:	mem
**	Date:	11/07/2007
**    
*****************************************************/
	
	If @@RowCount = 0
		Return

	Set NoCount on

	If Not (Update(Last_Affected) OR
			Update(Entered_By))
	Begin
		UPDATE T_Peptide_Prophet_DB_Parameters
		SET Last_Affected = GetDate(), 
			Entered_By = suser_sname()
		FROM T_Peptide_Prophet_DB_Parameters PPDP INNER JOIN 
			 inserted ON PPDP.Charge_State = inserted.Charge_State
	End

GO
