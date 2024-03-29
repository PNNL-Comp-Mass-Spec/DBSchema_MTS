/****** Object:  Database [MT_HistoricLog] ******/
CREATE DATABASE [MT_HistoricLog]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'MT_HistoricLog_dat', FILENAME = N'J:\SQLServerData\MT_HistoricLog_data.mdf' , SIZE = 840896KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 LOG ON 
( NAME = N'MT_HistoricLog_log', FILENAME = N'L:\SQLServerData\MT_HistoricLog_log.ldf' , SIZE = 353216KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
 COLLATE SQL_Latin1_General_CP1_CI_AS
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [MT_HistoricLog].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [MT_HistoricLog] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET ARITHABORT OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [MT_HistoricLog] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [MT_HistoricLog] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET  DISABLE_BROKER 
GO
ALTER DATABASE [MT_HistoricLog] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [MT_HistoricLog] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET RECOVERY FULL 
GO
ALTER DATABASE [MT_HistoricLog] SET  MULTI_USER 
GO
ALTER DATABASE [MT_HistoricLog] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [MT_HistoricLog] SET DB_CHAINING OFF 
GO
ALTER DATABASE [MT_HistoricLog] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [MT_HistoricLog] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
ALTER DATABASE [MT_HistoricLog] SET DELAYED_DURABILITY = DISABLED 
GO
GRANT CONNECT TO [MTAdmin] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Dev] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Lite] AS [dbo]
GO
GRANT CONNECT TO [MTUser] AS [dbo]
GO
ALTER DATABASE [MT_HistoricLog] SET  READ_WRITE 
GO
