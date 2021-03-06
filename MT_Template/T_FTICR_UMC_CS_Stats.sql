/****** Object:  Table [dbo].[T_FTICR_UMC_CS_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_FTICR_UMC_CS_Stats](
	[UMC_CS_Stats_ID] [int] IDENTITY(1,1) NOT NULL,
	[UMC_Results_ID] [int] NOT NULL,
	[Charge_State] [smallint] NOT NULL,
	[Member_Count] [smallint] NOT NULL,
	[Monoisotopic_Mass] [float] NOT NULL,
	[Abundance] [float] NOT NULL,
	[Elution_Time] [real] NULL,
	[Drift_Time] [real] NULL,
 CONSTRAINT [PK_T_FTICR_UMC_CS_Stats] PRIMARY KEY CLUSTERED 
(
	[UMC_CS_Stats_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Index [IX_T_FTICR_UMC_CS_Stats_UMCResultsID_ChargeState] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_FTICR_UMC_CS_Stats_UMCResultsID_ChargeState] ON [dbo].[T_FTICR_UMC_CS_Stats]
(
	[UMC_Results_ID] ASC,
	[Charge_State] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_CS_Stats]  WITH CHECK ADD  CONSTRAINT [FK_T_FTICR_UMC_CS_Stats_T_FTICR_UMC_Results] FOREIGN KEY([UMC_Results_ID])
REFERENCES [dbo].[T_FTICR_UMC_Results] ([UMC_Results_ID])
GO
ALTER TABLE [dbo].[T_FTICR_UMC_CS_Stats] CHECK CONSTRAINT [FK_T_FTICR_UMC_CS_Stats_T_FTICR_UMC_Results]
GO
