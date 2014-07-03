/****** Object:  Table [dbo].[T_Dataset_Stats_Scans] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Dataset_Stats_Scans](
	[Job] [int] NOT NULL,
	[Scan_Number] [int] NOT NULL,
	[Scan_Time] [real] NULL,
	[Scan_Type] [tinyint] NULL,
	[Total_Ion_Intensity] [float] NULL,
	[Base_Peak_Intensity] [float] NULL,
	[Base_Peak_MZ] [float] NULL,
	[Base_Peak_SN_Ratio] [real] NULL,
 CONSTRAINT [PK_T_Dataset_Stats_Scans] PRIMARY KEY CLUSTERED 
(
	[Job] ASC,
	[Scan_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Index [IX_T_Dataset_Stats_Scans_MZ] ******/
CREATE NONCLUSTERED INDEX [IX_T_Dataset_Stats_Scans_MZ] ON [dbo].[T_Dataset_Stats_Scans]
(
	[Base_Peak_MZ] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Dataset_Stats_Scans]  WITH CHECK ADD  CONSTRAINT [FK_T_Dataset_Stats_Scans_T_Analysis_Description] FOREIGN KEY([Job])
REFERENCES [dbo].[T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Dataset_Stats_Scans] CHECK CONSTRAINT [FK_T_Dataset_Stats_Scans_T_Analysis_Description]
GO
ALTER TABLE [dbo].[T_Dataset_Stats_Scans]  WITH CHECK ADD  CONSTRAINT [FK_T_Dataset_Stats_Scans_T_Dataset_Scan_Type_Name] FOREIGN KEY([Scan_Type])
REFERENCES [dbo].[T_Dataset_Scan_Type_Name] ([Scan_Type])
GO
ALTER TABLE [dbo].[T_Dataset_Stats_Scans] CHECK CONSTRAINT [FK_T_Dataset_Stats_Scans_T_Dataset_Scan_Type_Name]
GO
