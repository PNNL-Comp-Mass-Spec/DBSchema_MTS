if exists (select * from dbo.sysobjects where id = object_id(N'[T_QR_Export_Job]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_QR_Export_Job]
GO

CREATE TABLE [T_QR_Export_Job] (
	[jobkey] [int] IDENTITY (1, 1) NOT NULL ,
	[modified] [datetime] NOT NULL ,
	[statuskey] [int] NOT NULL ,
	[dbname] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[qid_list] [varchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[result] [varchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[email_address] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[prot_column] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[pep_column] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[rep_cnt_avg_min] [float] NOT NULL ,
	[propep_select] [smallint] NOT NULL ,
	[crosstab_select] [smallint] NOT NULL ,
	[send_mail] [smallint] NOT NULL ,
	[gen_pep] [bit] NOT NULL ,
	[include_prot] [bit] NOT NULL ,
	[gen_prot] [bit] NOT NULL ,
	[gen_prot_crosstab] [bit] NOT NULL ,
	[prot_avg] [bit] NOT NULL ,
	[gen_pep_crosstab] [bit] NOT NULL ,
	[pep_avg] [bit] NOT NULL ,
	[gen_propep_crosstab] [bit] NOT NULL ,
	[Verbose_Output_Columns] [bit] NOT NULL CONSTRAINT [DF_T_QR_Export_Job_Verbose_Output_Columns] DEFAULT (0),
	CONSTRAINT [PK_T_QR_Export_Job] PRIMARY KEY  CLUSTERED 
	(
		[jobkey]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


