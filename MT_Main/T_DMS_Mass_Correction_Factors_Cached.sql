/****** Object:  Table [dbo].[T_DMS_Mass_Correction_Factors_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Mass_Correction_Factors_Cached](
	[Mass_Correction_ID] [int] NOT NULL,
	[Mass_Correction_Tag] [char](8) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Description] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Monoisotopic_Mass_Correction] [float] NOT NULL,
	[Average_Mass_Correction] [float] NULL,
	[Affected_Atom] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Mass_Correction_Factors_Affected_Atom]  DEFAULT ('-'),
	[Original_Source] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL CONSTRAINT [DF_T_Mass_Correction_Factors_Original_Source]  DEFAULT (''),
	[Original_Source_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL CONSTRAINT [DF_T_Mass_Correction_Factors_Original_Source_Name]  DEFAULT (''),
	[Alternative_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Last_Affected] [datetime] NULL CONSTRAINT [DF_T_Mass_Correction_Factors_Last_Affected]  DEFAULT (getdate()),
 CONSTRAINT [PK_DMS_Mass_Correction_Factors_Cached] PRIMARY KEY CLUSTERED 
(
	[Mass_Correction_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Trigger [dbo].[trig_u_DMS_Mass_Correction_Factors_Cached] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE Trigger [dbo].[trig_u_DMS_Mass_Correction_Factors_Cached] on [dbo].[T_DMS_Mass_Correction_Factors_Cached]
For Update
AS
	If @@RowCount = 0
		Return

	if update(Mass_Correction_Tag) or 
	   update(Description) or 
	   update(Monoisotopic_Mass_Correction) or 
	   update(Average_Mass_Correction) or
	   update(Affected_Atom) or
	   update(Original_Source) or
	   update(Original_Source_Name) or
	   update(Alternative_Name)
			UPDATE T_DMS_Mass_Correction_Factors_Cached
			SET Last_Affected = GetDate()
			FROM T_DMS_Mass_Correction_Factors_Cached MCF INNER JOIN 
				 inserted ON MCF.Mass_Correction_ID = inserted.Mass_Correction_ID



GO
