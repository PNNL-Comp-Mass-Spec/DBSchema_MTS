/****** Object:  Table [dbo].[T_Seq_Mass_Update_History] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Seq_Mass_Update_History](
	[Batch_ID] [int] NOT NULL,
	[Seq_ID] [int] NOT NULL,
	[Monoisotopic_Mass_Old] [float] NULL,
	[Monoisotopic_Mass_New] [float] NULL,
	[Update_Date] [datetime] NULL,
 CONSTRAINT [PK_T_Mass_Update_History] PRIMARY KEY CLUSTERED 
(
	[Batch_ID] ASC,
	[Seq_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO
