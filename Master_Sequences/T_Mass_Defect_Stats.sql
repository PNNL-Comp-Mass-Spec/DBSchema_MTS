/****** Object:  Table [dbo].[T_Mass_Defect_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Mass_Defect_Stats](
	[Sampling_Size] [int] NOT NULL,
	[Mass_Start] [int] NOT NULL,
	[Mass_Defect_Bin] [real] NOT NULL,
	[Bin_Count] [int] NOT NULL,
	[Query_Date] [datetime] NOT NULL,
 CONSTRAINT [PK_T_Mass_Defect_Stats] PRIMARY KEY CLUSTERED 
(
	[Sampling_Size] ASC,
	[Mass_Start] ASC,
	[Mass_Defect_Bin] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Mass_Defect_Stats] ADD  CONSTRAINT [DF_T_Mass_Defect_Stats_Query_Date]  DEFAULT (getdate()) FOR [Query_Date]
GO
