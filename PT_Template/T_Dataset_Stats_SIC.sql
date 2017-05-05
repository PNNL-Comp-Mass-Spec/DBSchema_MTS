/****** Object:  Table [dbo].[T_Dataset_Stats_SIC] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Dataset_Stats_SIC](
	[Job] [int] NOT NULL,
	[Parent_Ion_Index] [int] NOT NULL,
	[MZ] [float] NULL,
	[Survey_Scan_Number] [int] NULL,
	[Frag_Scan_Number] [int] NOT NULL,
	[Optimal_Peak_Apex_Scan_Number] [int] NULL,
	[Peak_Apex_Override_Parent_Ion_Index] [int] NULL,
	[Custom_SIC_Peak] [tinyint] NULL,
	[Peak_Scan_Start] [int] NULL,
	[Peak_Scan_End] [int] NULL,
	[Peak_Scan_Max_Intensity] [int] NULL,
	[Peak_Intensity] [float] NULL,
	[Peak_SN_Ratio] [real] NULL,
	[FWHM_In_Scans] [int] NULL,
	[Peak_Area] [float] NULL,
	[Parent_Ion_Intensity] [real] NULL,
	[Interference_Score] [real] NULL,
 CONSTRAINT [PK_T_Dataset_Stats_SIC] PRIMARY KEY CLUSTERED 
(
	[Job] ASC,
	[Parent_Ion_Index] ASC,
	[Frag_Scan_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Index [IX_T_Dataset_Stats_SIC_FragScan_Job_OptimalPeakApex] ******/
CREATE NONCLUSTERED INDEX [IX_T_Dataset_Stats_SIC_FragScan_Job_OptimalPeakApex] ON [dbo].[T_Dataset_Stats_SIC]
(
	[Frag_Scan_Number] ASC,
	[Job] ASC,
	[Optimal_Peak_Apex_Scan_Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [IX_T_Dataset_Stats_SIC_MZ] ******/
CREATE NONCLUSTERED INDEX [IX_T_Dataset_Stats_SIC_MZ] ON [dbo].[T_Dataset_Stats_SIC]
(
	[MZ] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Dataset_Stats_SIC]  WITH CHECK ADD  CONSTRAINT [FK_T_Dataset_Stats_SIC_T_Analysis_Description] FOREIGN KEY([Job])
REFERENCES [dbo].[T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Dataset_Stats_SIC] CHECK CONSTRAINT [FK_T_Dataset_Stats_SIC_T_Analysis_Description]
GO
