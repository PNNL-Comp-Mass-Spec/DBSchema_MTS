/****** Object:  Table [dbo].[T_FTICR_UMC_Members] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_FTICR_UMC_Members](
	[UMC_Members_ID] [int] IDENTITY(1,1) NOT NULL,
	[UMC_Results_ID] [int] NOT NULL,
	[Member_Type_ID] [tinyint] NOT NULL,
	[Index_in_UMC] [int] NOT NULL,
	[Scan_Number] [int] NOT NULL,
	[MZ] [float] NOT NULL,
	[Charge_State] [smallint] NULL,
	[Monoisotopic_Mass] [float] NULL,
	[Abundance] [float] NULL,
	[Isotopic_Fit] [real] NULL,
	[Elution_Time] [real] NULL,
	[Is_Charge_State_Rep] [tinyint] NULL,
 CONSTRAINT [PK_T_FTICR_UMC_Members] PRIMARY KEY NONCLUSTERED 
(
	[UMC_Members_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_FTICR_UMC_Members] ******/
CREATE UNIQUE CLUSTERED INDEX [IX_T_FTICR_UMC_Members] ON [dbo].[T_FTICR_UMC_Members] 
(
	[UMC_Results_ID] ASC,
	[Index_in_UMC] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_FTICR_UMC_Members_Monoisotopic_Mass] ******/
CREATE NONCLUSTERED INDEX [IX_T_FTICR_UMC_Members_Monoisotopic_Mass] ON [dbo].[T_FTICR_UMC_Members] 
(
	[Monoisotopic_Mass] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_Members]  WITH NOCHECK ADD  CONSTRAINT [FK_T_FTICR_UMC_Members_T_FPR_UMC_Member_Type_Name] FOREIGN KEY([Member_Type_ID])
REFERENCES [T_FPR_UMC_Member_Type_Name] ([Member_Type_ID])
GO
ALTER TABLE [dbo].[T_FTICR_UMC_Members] CHECK CONSTRAINT [FK_T_FTICR_UMC_Members_T_FPR_UMC_Member_Type_Name]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_Members]  WITH CHECK ADD  CONSTRAINT [FK_T_FTICR_UMC_Members_T_FTICR_UMC_Results] FOREIGN KEY([UMC_Results_ID])
REFERENCES [T_FTICR_UMC_Results] ([UMC_Results_ID])
GO
ALTER TABLE [dbo].[T_FTICR_UMC_Members] CHECK CONSTRAINT [FK_T_FTICR_UMC_Members_T_FTICR_UMC_Results]
GO
