/****** Object:  Table [dbo].[T_Internal_Std_Components] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Internal_Std_Components](
	[Seq_ID] [int] NOT NULL,
	[Description] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Peptide] [varchar](850) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Monoisotopic_Mass] [float] NOT NULL,
	[Charge_Minimum] [int] NULL,
	[Charge_Maximum] [int] NULL,
	[Charge_Highest_Abu] [int] NULL,
	[Min_NET] [real] NULL,
	[Max_NET] [real] NULL,
	[Avg_NET] [real] NOT NULL,
	[Cnt_NET] [int] NULL,
	[StD_NET] [real] NULL,
	[PNET] [real] NULL,
 CONSTRAINT [PK_T_Internal_Std_Components] PRIMARY KEY CLUSTERED 
(
	[Seq_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO
