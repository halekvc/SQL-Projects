USE [DigitalLibrary]
GO
/****** Object:  StoredProcedure [dbo].[STSP_RERC14]    Script Date: 06/04/2017 09:42:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Hale Kavoosi>
-- Create date: <1394/07/05>
-- Description:	<شرط انتقال>
-- =============================================

ALTER PROCEDURE [dbo].[STSP_RERC14]
	@DocumentCode int,
	@StateCode int,
	@ReturnValue int = -1000 out ,				--مقدار اصلی خروجی روال
	@ErrorMessage nvarchar(512) =N'' out,		-- پیام برای نمایش در کارتابل
	@UserCodesXML nvarchar(4000) =N'' out,		-- انجام دهنگان مرحله بعدی
	@EmailXML nvarchar(4000) =N'' out,			--کاربران دریافت کننده ایمیل و متن آنها
	@SMSXML nvarchar(4000) =N'' out,			--کاربران دریافت کننده پیامک و متن آنها
	@MessageXML nvarchar(4000) =N'' out,			--کاربران دریافت کننده پيام و متن آنها
	@ExtraOutputXML nvarchar(4000) = N'' out		--برای خروج های اضافی با فرمت مشخص


AS
BEGIN
	
	Declare @creating_usercode int --كد كاربر ايجاد كننده فرم
	Declare @CompanyName nvarchar(200)=N''--نام واحد فناور
	Declare @CompanyCode int--کد واحد فناور
	DECLARE @CurrentDate NVARCHAR(100)--تاريخ جاري
	DECLARE @CurrentTime NVARCHAR(100) --ساعت جاري
	Declare @Expert_admission nvarchar(max)--نام كارشناس پذيرش 
	DECLARE @managerCode nvarchar(20)=N''--کد مسئول واحد فناور
	DECLARE @SeminarDate NVARCHAR(100)=N''--زمان برگزاری جلسه
	DECLARE @SeminarHour tinyint--ساعت جلسه مصاحبه
	DECLARE @SeminarMinute tinyint--دقيقه جلسه مصاحبه
	DECLARE @SeminarPlace nvarchar(max)--محل برگزاري جلسه
	DECLARE	@StateLetter nvarchar(10)-- كد مرحله جاري
    DECLARE @DTC_ParkSeminar int --کد جدول سمینار در پارک
	DECLARE @DTC_ArbiterDetermination int--كد جدول تعیین داور
	DECLARE @ArbiterDetermination_CompileDC int --شماره رکورد کامپایل تعیین داور
	DECLARE @ArbiterDetermination_DC int --شماره رکورد اصلی تعیین داور
	DECLARE @DTC_CompanyArbiter int --شماره جدول داوران واحد فناور
	DECLARE @EvaluationFormsConclusion bit--جمع بندي با توجه به عدم تكميل و ارسال فرم هاي ارزيابي كليه اعضاي جلسه و سلب حق اظهارنظر اعضايي كه تا كنون فرم هاي ارزيابي خود را تكميل و ارسال ننموده اند
	DECLARE @SupervisorResult nvarchar(50) =''--نتيجه بررسي سرپرست
    DECLARE @ExpertResult nvarchar(50) =''--نتيجه بررسي كارشناس
	DECLARE @ResponsibleSelection nvarchar(50) =''--مسئول جمع بندي فرم هاي ارزيابي
    DECLARE @ResponsibleExpert nvarchar(50) =''--كد كاربري كارشناس مسئول جمع بندي
    DECLARE @FileExpert nvarchar(50) =''--كد كاربري كارشناس بررسی کننده ی فایل سمینار
    DECLARE @ExpertOpinion nvarchar(100)=''--نظر كارشناس/سرپرست در خصوص جمع بندي
    DECLARE @SendingSms bit --بیت ارسال اسمس
    DECLARE @SelectiveMember xml    --افراد انتخاب شده در گردش
    DECLARE @MemberTemp table(DTC int,CompileDC int,UserCode int)  --یوزرکد کسانی که فرم های ارزیابی در مرحله ی اول هنوز در کارتابلشان است
    DECLARE @SMSUserTag NVARCHAR(MAX)=N'' --لیست افراد برای ارسال اسمس در مرحله هشتم
    DECLARE @SessionCancel int --بیت لغو جلسه
	----------------------------------------------------------------------------------
	DECLARE @Invited XML--مدعوين انتخاب شده 
	DECLARE @CountXML int--تعداد نفرات انتخاب شده
	DECLARE @UserCode int--یوزر کد نفرات انتخاب شده
	-------------------------------------------------------------------------------
		
	select
	@creating_usercode=RERC14H01_CreatingUsercode,
	@CompanyCode=RERC14H01_CompanyID,	
    @SeminarDate=dbo.getShamsiDate(left(RERC14H01_SeminarDate,11)),
    @SeminarHour=RERC14H01_SeminarHour,
    @SeminarMinute=RERC14H01_SeminarMinute,
    @SeminarPlace=RERC14H01_SeminarPlace,
    @managerCode=RERC14H01_ManagerUsercode,
    @EvaluationFormsConclusion=RERC14H03_EvaluationFormsConclusion,
    @SupervisorResult=RERC14H02_FileCheckResult,
	@ExpertResult=RERC14H02_SeminarCheckResult,
	@ResponsibleSelection= RERC14H02_Conclusion,
	@ResponsibleExpert=RERC14H02_ExpertChoose,
	@FileExpert=RERC14H02_SupervisorExpertChoose,
	@ExpertOpinion=RERC14H03_ExpertOpinion,
	@SendingSms=RERC14H03_SendingMessage,
	@SelectiveMember=RERC14H03_SessionMembers_SubFields_XML,
	@Invited=RERC14H01_InvitedSeminar_SubFields_XML,
	@SessionCancel=RERC14H01_SessionCancel
    
	from WSI_RERC_ParkSeminar_Compile WITH(NOLOCK) where DocumentCode=@DocumentCode 
	


    select @StateLetter=StateLetter from wfd_WorkflowsStates WITH(NOLOCK) where StateCode=@StateCode
    select @CurrentDate= dbo.getShamsiDate(left (GETDATE(),11))
    select @CurrentTime = right (GETDATE(),7)  
    select @Expert_admission= name+N' '+family from Users_PersonalInfo WITH(NOLOCK) where UserCode=@creating_usercode
    --select @managerCode= TDOO26H01_ManagerUsercode from WSI_TDOO_Company WITH(NOLOCK) where DocumentCode=@CompanyCode
    select @CompanyName= TDOO26H01_CompanyName from WSI_TDOO_Company WITH(NOLOCK) where DocumentCode=@CompanyCode
    select @DTC_ParkSeminar = DocumentTypeCode FROM Docs_Infos WITH(NOLOCK) where DocumentTypeName='WSI_RERC_ParkSeminar'
    select @DTC_ArbiterDetermination = DocumentTypeCode FROM Docs_Infos WITH(NOLOCK) where DocumentTypeName='WSI_RERC_ArbiterDetermination'
    select @DTC_CompanyArbiter = DocumentTypeCode FROM Docs_Infos WITH(NOLOCK) where DocumentTypeName='WSI_RERC_CompanyArbiter'
	select @ArbiterDetermination_CompileDC= dbo.PreviousWFDumentCode(@DTC_ParkSeminar,@DocumentCode,'RERC14')
	select @ArbiterDetermination_DC=MainDC from wfi_PoolInstances With(Nolock) 
		where CompileDC=@ArbiterDetermination_CompileDC and DTC=@DTC_ArbiterDetermination
		
	--بدست آوردن کد سرپرست پذیرش	
	DECLARE @Master_Expert INT
	=(SELECT UserCode FROM Users_Roles UR INNER JOIN Users_Roles_Managment RM ON UR.RoleCode=RM.RoleCode
	INNER JOIN Orgs_Units O ON UR.UnitCode=O.UnitCode WHERE UnitLetter='RE' AND RoleLetter='TDREMA')
	
	---------------------------------	
	--مسئول دفتر مديريت طرح هاي پژوهشي
	DECLARE @TDRPRO_UserCode int= 
	(Select distinct usercode from Users_Roles UR inner join Users_Roles_Managment URM ON
		UR.RoleCode=URM.RoleCode where URM.RoleLetter ='TDRPRO')
			
	 --مسئول دفتر معاون توسعه
	DECLARE @STTDRO_UserCode int= 
	(Select distinct usercode from Users_Roles UR inner join Users_Roles_Managment URM ON
		UR.RoleCode=URM.RoleCode where URM.RoleLetter ='STTDRO')
	-----------------------------------
 INSERT Into @MemberTemp
   	SELECT distinct DTC,CompileDC,UD.UserCode From wfi_UsersDashboards UD  
	 INNER JOIN wfi_WorkflowInstances WI ON UD.WFInstanceCode = WI.WFInstanceCode
	  INNER JOIN wfi_StateInstances SI ON SI.STInstanceCode = UD. STInstanceCode 
	   INNER JOIN wfd_WorkflowsStates WS ON WS.StateCode = SI.StateCode 
		  where WS.StateLetter IN('RERC17S01','RERC17S03') AND UD.Deleted = 0 and WI.PreviousWFInstanceCode= 
		   (select WFInstanceCode from wfi_WorkflowInstances WI with(Nolock)
			inner join wfi_PoolInstances P on P.PoolInstanceCode= WI.PoolInstanceCode 
			 inner join wfd_Workflows AS WF ON WF.WorkflowCode=WI.WorkflowCode
			   where CompileDC=@DocumentCode and DTC=@DTC_ParkSeminar and WF.WorkflowLetter ='RERC14') 	
--	***************************متغيرهاي مورد نياز براي لغو جلسه**********************************	
	IF @SessionCancel IN(1,2)
	BEGIN
		--شماره ركورد و جدول و كد گردش قبل تعيين داور 
		DECLARE @PreviousDC_Determination INT --شماره ركورد كامپايل كاربرگ
		DECLARE @PreviousDTC_Determination INT--كد جدول كاربرگ
		DECLARE @MainPreviousDC_Determination INT --شماره ركورد اصلي كاربرگ
		
		select @PreviousDC_Determination=CompileDC,@PreviousDTC_Determination=DTC 
		from dbo.wfi_PoolInstances P With (Nolock)inner join wfi_WorkflowInstances WI 
		on P.PoolInstanceCode=WI.PoolInstanceCode inner join dbo.wfd_Workflows W on WI.WorkflowCode=W.WorkflowCode
		where WI.WFInstanceCode IN
		(select PreviousWFInstanceCode from dbo.wfi_WorkflowInstances WI With (Nolock) 
		inner join dbo.wfd_Workflows W on WI.WorkflowCode=W.WorkflowCode
		inner join wfi_PoolInstances P on WI.PoolInstanceCode=P.PoolInstanceCode
		where DTC=@DTC_ArbiterDetermination and CompileDC=@ArbiterDetermination_CompileDC and W.WorkflowLetter='RERC11')
	
		SELECT @MainPreviousDC_Determination=MainDC from wfi_PoolInstances 
		    where CompileDC=@PreviousDC_Determination and DTC=@PreviousDTC_Determination
	
	
		--جدول موقت براي نگهداري كد كاربري مديرعامل/داوران/اعضاي شورا/مدعوين براي ارسال ايميل لغو جلسه
		DECLARE @CancelTemp TABLE (UserCode INT)
		DECLARE @SMSCancel_UserCode INT--كد كاربري دريافت كننده پيام لغو جلسه
		DECLARE @SMSCancel_UserTag nvarchar(max)=''--كد كاربري دريافت كنندگان پيام لغو جلسه
		DECLARE @ReasonCancel NVARCHAR(MAX)--علت لغو
		DECLARE @Cancel_UserCode INT--كد كارشناس/سرپرست پذيرش لغو كننده
		DECLARE @Cancel_Name NVARCHAR(200)--نام كارشناس/سرپرست پذيرش لغو كننده
		
		DECLARE @DTC_Cancel INT--كد جدول لغو جلسه
		=(SELECT DocumentTypeCode FROM Docs_Infos WHERE DocumentTypeName='WSI_STOO_SessionCancel')
		
		SELECT top 1
			@ReasonCancel=STOO14H01_ReasonSessionCancel,
			@Cancel_UserCode=STOO14H01_CreatingUserCode,
			@Cancel_Name=DBO.GetUserNameFamily(STOO14H01_CreatingUserCode)
		FROM WSI_STOO_SessionCancel S INNER JOIN wfi_WorkflowInstances WI
		ON S.DocumentCode=WI.MainDC INNER JOIN wfi_PoolInstances P
		ON WI.PoolInstanceCode=P.PoolInstanceCode
		WHERE STOO14H01_SessionType='RERC14' AND STOO14H01_SessionCancel=@DocumentCode
		AND P.DTC=@DTC_Cancel ORDER BY WI.WFFinishDate DESC
		
		DECLARE @RoleName NVARCHAR(100)--نام نفش لغو كننده
		
		IF 'TDREMA' IN (SELECT DISTINCT UR.RoleLetter FROM Users_Roles_Managment UR 
		INNER JOIN Users_Roles U ON UR.RoleCode=U.RoleCode WHERE UserCode=@Cancel_UserCode)
			SET @RoleName=N'سرپرست جذب و پذيرش واحدهاي فناوري'
			
		ELSE IF 'TDREEX' IN (SELECT DISTINCT UR.RoleLetter FROM Users_Roles_Managment UR 
		INNER JOIN Users_Roles U ON UR.RoleCode=U.RoleCode WHERE UserCode=@Cancel_UserCode)
			SET @RoleName=N'كارشناس جذب و پذيرش واحدهاي فناوري'

		INSERT INTO @CancelTemp
			--داوران واحد فناوري
			SELECT Cast(CA.RERC34H01_ArbiterName as int) From WSI_RERC_CompanyArbiter CA With(Nolock) 
			where RERC34H01_ArbiterOpinion= 'Accept' and CA.DocumentCode IN 
			(Select RelatedDC from Docs_Related_Records_Compile With(Nolock) 
			where MasterDTC=@DTC_ArbiterDetermination and MasterDC= @ArbiterDetermination_DC
			and MasterInCompile=0 and RelatedInCompile=0 and RelatedDTC=@DTC_CompanyArbiter)			
	
			UNION
			
			--كد كاربري مديرعامل
			Select @ManagerCode	

     IF @StateLetter<>'RERC14S01'
     
		INSERT INTO @CancelTemp

			--كد كارشناسان روابط عمومي
			SELECT DISTINCT UR.UserCode FROM Users_Roles UR 
			INNER JOIN Users_Roles_Managment RM ON UR.RoleCode=RM.RoleCode WHERE RoleLetter='STGREX'
			
			UNION
			
			--کد کاربری اعضای شورای پذیرش را مي خواند
			select UserCode from Users_Roles UR 
			inner join Users_Roles_Managment URM on UR.RoleCode=URM.RoleCode
			inner join Orgs_Units O ON UR.UnitCode=O.UnitCode
			where RoleLetter='RERC44CO' AND UnitLetter='RECO'
			
					
		--كد كاربري مدعوين
		IF @Invited IS NOT NULL
		BEGIN
			set arithabort on                   
			Set @CountXML= @Invited.value('count(/Records/Record/@RowID)','int')
			
			while @CountXML<>0
			begin  
				set arithabort on
				set @UserCode= @Invited.value(N'(Records/Record/Field[@name="RERC14H01_InvitedSeminar"]/@Value)[1]','INT')

				--اگر اين يوزركد در جدول افراد وجود ندارد
				if not exists (select UserCode from @CancelTemp where usercode =@UserCode)
					insert into @CancelTemp select @UserCode
					
				set arithabort on
				set @Invited.modify('delete /Records/Record [1]')
				set @CountXML=@CountXML-1
			end  
		END		
		
		WHILE (SELECT COUNT(*) FROM @CancelTemp ) <> 0  
		BEGIN
			SELECT TOP 1 @SMSCancel_UserCode = UserCode FROM @CancelTemp ORDER BY UserCode ASC 
			 
			if(@SMSCancel_UserTag Not like '%"'+cast(@SMSCancel_UserCode as nvarchar(max))+'"%')--اگر اين يوزركد در ليست يوزرتگ وجود ندارد
			
				SET  @SMSCancel_UserTag= @SMSCancel_UserTag + '<UserCode Value = "' + CONVERT(NVARCHAR(10),@SMSCancel_UserCode) + '" />' 
			
			-- حذف داده استفاده شده از جدول تمپ
			DELETE FROM @CancelTemp WHERE UserCode= @SMSCancel_UserCode
		end--پايان حلقه
		
		--حذف فرم های ارزیابی از كارتابل اعضای جلسه
		EXEC Gen_AutoFinishWF @MDTC=@DTC_ParkSeminar,@MDC=@DocumentCode,@MWFLetter='RERC14',@WFLetter='RERC17'
       
		--آپديت فيلد لغو جلسه روي گردش تصاوير جلسه
		UPDATE WSI_GRAV_InterviwePictures_Compile
		SET GRAV01H01_SessionCancel=1 WHERE DocumentCode IN
		
			(SELECT P.CompileDC FROM wfi_PoolInstances P 
			INNER JOIN wfi_WorkflowInstances WI ON P.PoolInstanceCode=WI.PoolInstanceCode
			INNER JOIN wfd_Workflows W ON WI.WorkflowCode=W.WorkflowCode
			WHERE W.WorkflowLetter='GRAV01' AND WI.WFFinished=0
			AND WI.PreviousWFInstanceCode IN
				(SELECT WI.WFInstanceCode FROM wfi_WorkflowInstances WI
				INNER JOIN wfi_PoolInstances P  ON WI.PoolInstanceCode=P.PoolInstanceCode
				INNER JOIN wfd_Workflows W ON WI.WorkflowCode=W.WorkflowCode
				WHERE P.DTC=@DTC_ParkSeminar AND P.CompileDC=@DocumentCode AND W.WorkflowLetter='RERC14'))
		
		--حذف فرم تصاوير جلسه از كارتابل كارشناسان روابط عمومي
		EXEC Gen_AutoFinishWF @MDTC=@DTC_ParkSeminar,@MDC=@DocumentCode,@MWFLetter='RERC14',@WFLetter='GRAV01'
		
		IF @SessionCancel=2--اگر لغو پذيرش انتخاب شده باشد
		BEGIN
			--آپديت وضعيت واحد فناور
			--وضعيت واحد فناور رد شده 2 مي شود
			Update WSI_TDOO_Company SET TDOO26H01_AdmissionStatus=2 where DocumentCode= @CompanyCode
			
			--غيرفعال كردن پرسنل اين واحد فناور
			UPDATE WSI_TDOO_PersonnelCooperation SET TDOO01H01_Status =1 WHERE TDOO01H01_CompanyID= @CompanyCode
			
			--وضعيت گردش تكميل واحد پارک غيرفعال يا 0 مي شود
			Update WSI_RERC_Park SET RERC06H01_RequestStatus= 0 
			where DocumentCode=@MainPreviousDC_Determination
				
			SET @ReturnValue = 11
			SET @ErrorMessage = N''
			SET @UserCodesXML ='<UserRoot>'+
							 '	<UserCode Value="-1" />'+
							 '</UserRoot>'--اتمام گردش
							   
			SET @EmailXML=N'<EmailRoot>'+
						N'	<Email Text=" با سلام&lt;br&gt;&lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;احتراما به استحضار مي رساند طي لغو درخواست پذيرش واحد فناور « '
						+@CompanyName+N' » به علت « '+@ReasonCancel+N' » ، جلسه مصاحبه جهت پذيرش واحد فناور در مركز پارک و داوري داخلي در تاریخ '+@SeminarDate+N' برگزار نمي گردد.'
						+N'&lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;با تشكر&lt;br&gt;&lt;b&gt;'
						+@Cancel_Name+N'&lt;/b&gt;&lt;br&gt; '+@RoleName+'&lt;/p&gt;" >'+
						+@SMSCancel_UserTag+--گيرنده: مديرعامل/داوران/اعضاي شورا
						N'	</Email>'+
						N'</EmailRoot>' 
						
			SET @SMSXML = N'<SMSRoot>'+
						N'	<SMS Text="احتراما به استحضار مي رساند طي لغو درخواست پذيرش واحد فناور « '+@CompanyName
						+N' » به علت « '+@ReasonCancel+N' » ، جلسه مصاحبه جهت پذيرش واحد فناور در مركز پارک و داوري داخلي در تاریخ '+@SeminarDate+N' برگزار نمي گردد.">'
						+@SMSCancel_UserTag+--گيرنده: مديرعامل/داوران/اعضاي شورا/مدعوين
						'<UserCode Value="'+CONVERT(nvarchar(10),@TDRPRO_UserCode)+'" />'+  --مسئول دفتر مديريت طرح هاي پژوهشي
						'<UserCode Value="'+CONVERT(nvarchar(10),@STTDRO_UserCode)+'" />'+  --مسئول دفتر معاون توسعه
						N'	</SMS>'+
						N'</SMSRoot>'
							
			SET @MessageXML =N''
			SET @ExtraOutputXML = N''			
		END
		
		ELSE IF @SessionCancel=1--اگر تغيير زمان جلسه انتخاب شده باشد
		BEGIN
			--آپديت فيلد لغو جلسه با صفر
			Update WSI_RERC_ParkSeminar_Compile SET RERC14H01_SessionCancel= 0 
			where DocumentCode=@DocumentCode
				
			SET @ReturnValue = 1--بازگشت به مرحله اول
			SET @ErrorMessage = N''
			SET @UserCodesXML = '<UserRoot>'+
								'<UserCode Value="'+CONVERT(NVARCHAR,@Creating_Usercode) +'" />'+
								'</UserRoot>' 
							   
			SET @EmailXML=N'<EmailRoot>'+
						N'	<Email Text=" با سلام&lt;br&gt;&lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;احتراما به استحضار مي رساند طي تغيير زمان جلسه مصاحبه واحد فناور « '
						+@CompanyName+N' » جهت پذيرش در مركز پارک و داوري داخلي به علت « '+@ReasonCancel+N' » ، جلسه در تاريخ '+@SeminarDate+N' برگزار نمي گردد.'
						+N' زمان بعدي جلسه متعاقبا اعلام مي گردد.&lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;با تشكر&lt;br&gt;&lt;b&gt;'
						+@Cancel_Name+N'&lt;/b&gt;&lt;br&gt; '+@RoleName+'&lt;/p&gt;" >'+
						+@SMSCancel_UserTag+--گيرنده: مديرعامل/داوران/اعضاي شورا/مدعوين
						N'	</Email>'+
						N'</EmailRoot>' 
						
			SET @SMSXML=N'<SMSRoot>'+
						N'	<SMS Text="احتراما به استحضار مي رساند طي تغيير زمان جلسه مصاحبه واحد فناور « '
						+@CompanyName+N' » جهت پذيرش در مركز پارک و داوري داخلي به علت « '+@ReasonCancel
						+N' » ، جلسه در تاريخ '+@SeminarDate+N' برگزار نمي گردد.'
						+N' زمان بعدي جلسه متعاقبا اعلام مي گردد.">'
						+@SMSCancel_UserTag+--گيرنده: مديرعامل/داوران/اعضاي شورا/مدعوين
						'<UserCode Value="'+CONVERT(nvarchar(10),@TDRPRO_UserCode)+'" />'+  --مسئول دفتر مديريت طرح هاي پژوهشي
						'<UserCode Value="'+CONVERT(nvarchar(10),@STTDRO_UserCode)+'" />'+  --مسئول دفتر معاون توسعه
						N'	</SMS>'+
						N'</SMSRoot>'
							
			SET @MessageXML =N''
			SET @ExtraOutputXML = N''			
		END
	END			   
----------------------------------------------------------------------------------------------------------      
  ELSE
   BEGIN
  --  مرحله اول          		
	IF (@StateLetter=N'RERC14S01') --statecode=105
	Begin
		---------آپدیت فیلدهای توضیحی تب آخر برای اینکه NULL نباشند و آپدیت فرم ها درست انجام شود--------
         UPDATE WSI_RERC_ParkSeminar_Compile set 
		  RERC14H03_ApplicantActivitiesFitness=''
		, RERC14H03_WeaknessesOfTechnologyOrProduct=''
		, RERC14H03_StrengthsOfTechnologyOrProduct=''
		, RERC14H03_WeaknessesOfHumanResources=''
		, RERC14H03_StrengthsOfHumanResources=''
		, RERC14H03_WeaknessesOfEconomicActivities=''
		, RERC14H03_StrengthsOfEconomicActivities=''
		, RERC14H03_StrengthsOfOperationalPrograms=''
		, RERC14H03_WeaknessesOfOperationalPrograms=''
		, RERC14H03_StrengthsOfFacilitiesAvailable=''
		, RERC14H03_WeaknessesOfFacilitiesAvailable=''
		, RERC14H03_EvaluationOfResearchActivities=''
		, RERC14H03_OtherIncentivesExplain=''
		, RERC14H02_FileDescription=''
				where DocumentCode=@DocumentCode   	
 		
		---------------------------------------------------------------------------------------------- 	
	--تعيين محل جلسه مصاحبه براساس مقدار كمبو
	if(@SeminarPlace=1)
		SET @SeminarPlace=  N'سالن جلسات شيخ بهايي'
	
	else if(@SeminarPlace=2)
		SET @SeminarPlace= N'سالن جلسات ايريس'
	
	else if(@SeminarPlace=3)
		SET @SeminarPlace= N'اتاق كنفرانس'
		
	else if(@SeminarPlace=4)
		SELECT @SeminarPlace=RERC14H01_PlaceExplanation FROM WSI_RERC_ParkSeminar_Compile 
			WHERE DocumentCode = @DocumentCode  
	-------------------------------------------------
	--تعريف متغيرهاي كد كاربري هاي موردنياز در SMS
	DECLARE @ParkSupervisor_User int --كد كاربري سرپرست پارک
	DECLARE @Assistant_User int--كد كاربري معاون توسعه
	DECLARE @ProjectsSupervisor_User int--كد كاربري سرپرست طرح هاي پژوهشي
	
	--كد كاربري سرپرست مركز پارک
	select distinct @ParkSupervisor_User= UPI.UserCode from Users_PersonalInfo UPI With(Nolock) 
		inner join Users_Roles UR on UPI.UserCode=UR.UserCode
			inner join Users_Roles_Managment URM on UR.RoleCode=URM.RoleCode
			 inner join Orgs_Units O ON UR.UnitCode=O.UnitCode  
				where URM.RoleLetter='TDPAMA' AND UnitLetter='PA'
				
	--كد كاربري معاون توسعه واحدهاي فناوري
	select  distinct @Assistant_User=UPI.UserCode from Users_PersonalInfo UPI With(Nolock)
		inner join Users_Roles UR on UPI.UserCode=UR.UserCode
			inner join Users_Roles_Managment URM on UR.RoleCode=URM.RoleCode 
				inner join Orgs_Units O ON UR.UnitCode=O.UnitCode 
			    	where URM.RoleLetter='STTDMA' AND UnitLetter='TD'
				
	--كد كاربري سرپرست طرح هاي پژوهشي												
	select distinct @ProjectsSupervisor_User=UPI.UserCode from Users_PersonalInfo UPI With(Nolock)
		inner join Users_Roles UR on UPI.UserCode=UR.UserCode
			inner join Users_Roles_Managment URM on UR.RoleCode=URM.RoleCode
				inner join Orgs_Units O ON UR.UnitCode=O.UnitCode  
				  where URM.RoleLetter='TDRPMA'	AND UnitLetter='RP'	
				
													
	DECLARE @SMSTemp1 TABLE (UserCode INT)--جدول برای نگهداری کد کاربری داوران و نمايندگان موسسات و نمايندگان شوراي علمي
	DECLARE @MembersTEMP TABLE (UserCode INT)--جدول برای نگهداری کد کاربری اعضای شورای پذیرش
	
	-- فايل ایکس ام ال برای نگهداری کد شروع كنندگان گردش ارزيابي
	DECLARE @UserTag nvarchar(max)= '' 
	
	IF(@UserTag Not like '%"'+cast(@ParkSupervisor_User as nvarchar(max))+'"%')--اگر يوزركد سرپرست مركز پارک در ليست يوزرتگ وجود ندارد
	  SET  @UserTag=  @UserTag + '<UserCode Value = "' + CONVERT(NVARCHAR(10),@ParkSupervisor_User) + '" />'
	   
	IF(@UserTag Not like '%"'+cast(@Assistant_User as nvarchar(max))+'"%')--اگر يوزركد معاون توسعه واحدهاي فناوري در ليست يوزرتگ وجود ندارد
	  SET  @UserTag=  @UserTag + '<UserCode Value = "' + CONVERT(NVARCHAR(10),@Assistant_User) + '" />' 
	  
	IF(@UserTag Not like '%"'+cast(@ProjectsSupervisor_User as nvarchar(max))+'"%')--اگر يوزركد سرپرست طرح هاي پژوهشي در ليست يوزرتگ وجود ندارد
	  SET  @UserTag=  @UserTag + '<UserCode Value = "' + CONVERT(NVARCHAR(10),@ProjectsSupervisor_User) + '" />' 

	
	DECLARE @MembersUserTag XML  -- فايل ایکس ام ال برای نگهداری کد اعضای شورای پذیرش
	DECLARE @SMSUserTag1 XML  -- فايل ایکس ام ال برای نگهداری کد داوران
	
	DECLARE @MemberUsercode INT -- متغیر نگهدارنده کد کاربری عضو شورای پذیرش
	DECLARE @SMSUsercode INT -- متغیر نگهدارنده کد کاربری داور

	DECLARE @SMSXMLTEMP XML = N'<SMSRoot>'+
	N'	<SMS Text="احتراما به اطلاع مي رساند جلسه مصاحبه جهت پذيرش واحد فناور « '+@CompanyName+N' » در مركز پارک در تاريخ '+
	@SeminarDate +N' در ساعت '+Cast(@SeminarHour as nvarchar(100)) +N':'+Cast(@SeminarMinute as nvarchar(100))+
	N' درمحل '+@SeminarPlace+N' برگزار مي گردد.'+'" >'+
	N'		<UserCode Value="'+Cast(@ParkSupervisor_User as nvarchar(20))+'" />'+ --گيرنده: سرپرست پارک
	--N'		<UserCode Value="'+Cast(@Assistant_User as nvarchar(20))+'" />'+ --گيرنده: معاون توسعه واحدهاي فناوري
	--N'		<UserCode Value="'+Cast(@ProjectsSupervisor_User as nvarchar(20))+'" />'+ --گيرنده: سرپرست طرح هاي پژوهشي
	'<UserCode Value="'+CONVERT(nvarchar(10),@TDRPRO_UserCode)+'" />'+  --مسئول دفتر مديريت طرح هاي پژوهشي
	--'<UserCode Value="'+CONVERT(nvarchar(10),@STTDRO_UserCode)+'" />'+  --مسئول دفتر معاون توسعه
	N'	</SMS>'+
	N'</SMSRoot>'
	
	DECLARE @MessageXMLTEMP XML = N'<MessageRoot>'+
	N'<Message Text="احتراما به اطلاع مي رساند جلسه مصاحبه جهت پذيرش واحد فناور « '+@CompanyName+N' » در مركز پارک در تاريخ '+
	@SeminarDate +N' در ساعت '+Cast(@SeminarHour as nvarchar(100)) +N':'+Cast(@SeminarMinute as nvarchar(100))+
	N' درمحل '+@SeminarPlace+N' برگزار مي گردد. '+N' با تشكر '+@Expert_admission+
	N' كارشناس جذب و پذيرش واحدهاي فناوري '+
	'" >'+
	N'	</Message>'+
	N'</MessageRoot>'
	
	DECLARE @EmailXMLTEMP XML =N'<EmailRoot>'+
	N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام،&lt;br&gt;احتراما به استحضار مي رساند فرم «'+
	N'&lt;font color=&quot;blue&quot;&gt;'+N'ارزيابي پارک '+ '&lt;/font&gt;'+
	N'» در تاريخ '+@CurrentDate+N' ساعت '+@CurrentTime+N' در كارتابل جنابعالي قرار گرفته است.&lt;br&gt;'+
	N'ضمنا به اطلاع مي رساند جلسه مصاحبه جهت پذيرش واحد فناور « '+@CompanyName+N' » در مركز پارک در تاريخ '+
	@SeminarDate +N' ساعت '+Cast(@SeminarHour as nvarchar(50)) +N':'+Cast(@SeminarMinute as nvarchar(50))+
	N' در محل '+@SeminarPlace+N' برگزار مي گردد.'
	+N'&lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;با تشكر&lt;br&gt;&lt;b&gt;'
	+@Expert_admission+N'&lt;/b&gt; كارشناس جذب و پذيرش واحدهاي فناوري&lt;/p&gt;" >'+
	N'		<UserCode Value="'+Cast(@ParkSupervisor_User as nvarchar(20))+'" />'+ --گيرنده: سرپرست پارك
	N'		<UserCode Value="'+Cast(@Assistant_User as nvarchar(20))+'" />'+ --گيرنده: معاون توسعه واحدهاي فناوري
	N'		<UserCode Value="'+Cast(@ProjectsSupervisor_User as nvarchar(20))+'" />'+ --گيرنده: سرپرست طرح هاي پژوهشي
	N'	</Email>'+
	N'</EmailRoot>'
---=====================================================================================================================
		--ايجاد جدول تمپ براي نگهداري يوزركد مدعوين انتخاب شده     

		IF @Invited IS NOT NULL
		BEGIN
			set arithabort on                   
			Set @CountXML= @Invited.value('count(/Records/Record/@RowID)','int')
			
			while @CountXML<>0
			begin  
				set arithabort on
				set @UserCode= @Invited.value(N'(Records/Record/Field[@name="RERC14H01_InvitedSeminar"]/@Value)[1]','INT')

				--اگر اين يوزركد در جدول افراد انتخاب شده وجود ندارد
				if not exists (select UserCode from @SMSTemp1 where usercode =@UserCode)
					insert into @SMSTemp1 select @UserCode
					
				set arithabort on
				set @Invited.modify('delete /Records/Record [1]')
				set @CountXML=@CountXML-1
			end  
		END	
	----------------------------------------------------------------------------------------
		
			--کد کاربری داوران را از فرم داوران واحد فناوري وابسته در گردش تعيين داور مي خواند
			IF (select TOP 1 RelatedInCompile from Docs_Related_Records_Compile 
					where MasterDTC=@DTC_ArbiterDetermination and MasterDC= @ArbiterDetermination_DC
						and MasterInCompile=0 and RelatedDTC=@DTC_CompanyArbiter)=1														
			begin
		    --ايجاد جدول تمپ براي نگهداري يوزركد داوران، نمايندگان موسسات و نمايندگان شوراي علمي 
			INSERT INTO @SMSTemp1(UserCode)

			SELECT Cast(CA.RERC34H01_ArbiterName as int) From WSI_RERC_CompanyArbiter_Compile CA With(Nolock) 
				where RERC34H01_ArbiterOpinion= 'Accept' and CA.DocumentCode IN 
				(Select RelatedDC from Docs_Related_Records_Compile With(Nolock) 
					where MasterDTC=@DTC_ArbiterDetermination and MasterDC= @ArbiterDetermination_DC
						and MasterInCompile=0 and RelatedInCompile=1 
							and RelatedDTC=@DTC_CompanyArbiter
								and Suspended=0)
			end
								
			ELSE
			begin 
		    --ايجاد جدول تمپ براي نگهداري يوزركد داوران، نمايندگان موسسات و نمايندگان شوراي علمي 
			INSERT INTO @SMSTemp1(UserCode)
			 
 			SELECT Cast(CA.RERC34H01_ArbiterName as int) From WSI_RERC_CompanyArbiter CA With(Nolock) 
				where RERC34H01_ArbiterOpinion= 'Accept' and CA.DocumentCode IN 
				(Select RelatedDC from Docs_Related_Records_Compile With(Nolock) 
					where MasterDTC=@DTC_ArbiterDetermination and MasterDC= @ArbiterDetermination_DC
						and MasterInCompile=0 and RelatedInCompile=0 
							and RelatedDTC=@DTC_CompanyArbiter)
			end												
									
	    --ايجاد جدول تمپ براي نگهداري يوزركد داوران، نمايندگان موسسات و نمايندگان شوراي علمي 
		INSERT INTO @SMSTemp1(UserCode)
			    
		--  کد کاربری نمايندگان موسسات را مي خواند
		select  UPI.UserCode from Users_PersonalInfo UPI With(Nolock)
			inner join Users_Roles UR on UPI.UserCode=UR.UserCode
				inner join Users_Roles_Managment URM on UR.RoleCode=URM.RoleCode
					inner join Orgs_Units O ON UR.UnitCode=O.UnitCode 
						where URM.RoleLetter='STTDCR' AND UnitLetter='TD'
						
		Union
		--  کد کاربری نمايندگان شوراي علمي را مي خواند
		select UPI.UserCode from Users_PersonalInfo UPI With(Nolock)
			inner join Users_Roles UR on UPI.UserCode=UR.UserCode
				inner join Users_Roles_Managment URM on UR.RoleCode=URM.RoleCode 
					inner join Orgs_Units O ON UR.UnitCode=O.UnitCode 
						where URM.RoleLetter='STTDSC' AND UnitLetter='TD'
						
		Union
		--کد کاربری اعضای شورای پذیرش را مي خواند
			select UserCode from Users_Roles UR 
				inner join Users_Roles_Managment URM on UR.RoleCode=URM.RoleCode
					inner join Orgs_Units O ON UR.UnitCode=O.UnitCode
						where RoleLetter='RERC44CO' AND UnitLetter='RECO'	
------------------------------------------------------------------------------------							
		-- تا زمانی که در لیست کد کاربری وجود دارداز بالاترين ركوردش مقادير را خوانده                 
		WHILE (SELECT COUNT(UserCode) FROM @SMSTemp1 ) <> 0  
		BEGIN
			SELECT TOP 1 @SMSUsercode = UserCode FROM @SMSTemp1 ORDER BY UserCode ASC
			
			--يوزكد داوران، نمايندگان موسسات و نمايندگان شوراي علمي
			--شروع كنندگان گردش ارزيابي پارك
			
		   if(@UserTag Not like '%"'+cast(@SMSUsercode as nvarchar(max))+'"%')--اگر اين يوزركد در ليست يوزرتگ وجود ندارد
			
				SET  @UserTag=  @UserTag + '<UserCode Value = "' + CONVERT(NVARCHAR(10),@SMSUsercode) + '" />' 
			
			SET  @SMSUserTag1= '<UserCode Value = "' + CONVERT(NVARCHAR(10),@SMSUsercode) + '" />'

			 --اگر اين يوزركد در ليست يوزرتگ وجود ندارد
			if cast(@SMSXMLTEMP as nvarchar(max)) NOT like ('%"'+CAST(@SMSUsercode AS NVARCHAR(20))+'"%')
			  begin			 
				SET ARITHABORT ON
			    SET @SMSXMLTEMP.modify('insert sql:variable("@SMSUserTag1") into (/SMSRoot/SMS)[1]')
			  end
			
			 --اگر اين يوزركد در ليست يوزرتگ وجود ندارد
			 --اگر عضو شورای پذیرش است ایمیل ارسال نشود
			if cast(@EmailXMLTEMP as nvarchar(max)) NOT like ('%"'+CAST(@SMSUsercode AS NVARCHAR(20))+'"%') 
			    AND 'RERC44CO' NOT IN(select RoleLetter from Users_Roles UR 
					inner join Users_Roles_Managment URM on UR.RoleCode=URM.RoleCode						
						where UserCode=@SMSUsercode	)
			  begin			
				SET ARITHABORT ON
			    SET @EmailXMLTEMP.modify('insert sql:variable("@SMSUserTag1") into (/EmailRoot/Email)[1]')
			  end
			  			
			--SET ARITHABORT ON
			--SET @SMSXMLTEMP.modify('insert sql:variable("@SMSUserTag1") into (/SMSRoot/SMS)[1]')
			--SET @EmailXMLTEMP.modify('insert sql:variable("@SMSUserTag1") into (/EmailRoot/Email)[1]')
			
			-- حذف داده استفاده شده از جدول تمپ
			DELETE FROM @SMSTemp1 WHERE UserCode= @SMSUsercode
			
		end--پايان حلقه	

---======================================================================================================================
		INSERT INTO @MembersTEMP (UserCode)
		
		--کد کاربری اعضای شورای پذیرش را مي خواند
		select UserCode from Users_Roles UR WITH (NOLOCK) 
			inner join Users_Roles_Managment URM WITH (NOLOCK) on UR.RoleCode=URM.RoleCode
				inner join Orgs_Units O ON UR.UnitCode=O.UnitCode
					where RoleLetter='RERC44CO' AND UnitLetter='RE'
					
	-- تا زمانی که در لیست اعضای شورای پذیرش  کد کاربری وجود دارداز بالاترين ركوردش مقادير را خوانده                 
	WHILE (SELECT COUNT(UserCode) FROM @MembersTEMP) <> 0  
	BEGIN
		SELECT TOP 1 @MemberUsercode = UserCode FROM @MembersTEMP ORDER BY UserCode ASC
		
		-- if(@MemberUsercode not like  @UserTag)--اگر اين يوزركد در ليست يوزرتگ وجود ندارد
		--SET  @UserTag= @UserTag+ '<UserCode Value = "' + CONVERT(NVARCHAR(10),@MemberUsercode) + '" />'  
		 
		SET @MembersUserTag = '<UserCode Value = "' + CONVERT(NVARCHAR(10),@MemberUsercode) + '" />'
		
		--SET @SMSXMLTEMP.modify('insert sql:variable("@MembersUserTag") into (/SMSRoot/SMS)[1]')
		
		SET ARITHABORT ON
		SET @MessageXMLTEMP.modify('insert sql:variable("@MembersUserTag") into (/MessageRoot/Message)[1]')
		-- حذف داده استفاده شده از جدول تمپ
		DELETE FROM @MembersTEMP WHERE UserCode= @MemberUsercode
	end--پايان حلقه
			---------------------------------------------------------------------------------------------------------
		DECLARE @REceiveMailTemp TABLE (UserCode INT)
		DECLARE @REceiveMailUserTag nvarchar(max)=''--كد كاربري داوران
		DECLARE @REceiveMailUsercode nvarchar(max)='' ---كد كاربري داور
		
			--کد کاربری داوران را از فرم داوران واحد فناوري وابسته در گردش تعيين داور مي خواند
			IF (select TOP 1 RelatedInCompile from Docs_Related_Records_Compile 
					where MasterDTC=@DTC_ArbiterDetermination and MasterDC= @ArbiterDetermination_DC
						and MasterInCompile=0 and RelatedDTC=@DTC_CompanyArbiter)=1														
			begin
			--ايجاد جدول تمپ براي نگهداري يوزركد داوران و مدير واحد فناور
		    INSERT INTO @REceiveMailTemp

			SELECT Cast(CA.RERC34H01_ArbiterName as int) From WSI_RERC_CompanyArbiter_Compile CA With(Nolock) 
				where RERC34H01_ArbiterOpinion= 'Accept' and CA.DocumentCode IN 
				(Select RelatedDC from Docs_Related_Records_Compile With(Nolock) 
					where MasterDTC=@DTC_ArbiterDetermination and MasterDC= @ArbiterDetermination_DC
						and MasterInCompile=0 and RelatedInCompile=1 
							and RelatedDTC=@DTC_CompanyArbiter
								and Suspended=0)
			end
								
			ELSE
			begin 
			--ايجاد جدول تمپ براي نگهداري يوزركد داوران و مدير واحد فناور
		    INSERT INTO @REceiveMailTemp
			 
 			SELECT Cast(CA.RERC34H01_ArbiterName as int) From WSI_RERC_CompanyArbiter CA With(Nolock) 
				where RERC34H01_ArbiterOpinion= 'Accept' and CA.DocumentCode IN 
				(Select RelatedDC from Docs_Related_Records_Compile With(Nolock) 
					where MasterDTC=@DTC_ArbiterDetermination and MasterDC= @ArbiterDetermination_DC
						and MasterInCompile=0 and RelatedInCompile=0 
							and RelatedDTC=@DTC_CompanyArbiter)
			end												
									
			--ايجاد جدول تمپ براي نگهداري يوزركد داوران و مدير واحد فناور
		    INSERT INTO @REceiveMailTemp
		    
			Select @managerCode					
			
			Union
			--  کد کاربری نمايندگان موسسات را مي خواند
			select  UPI.UserCode from Users_PersonalInfo UPI With(Nolock)
				inner join Users_Roles UR on UPI.UserCode=UR.UserCode
					inner join Users_Roles_Managment URM on UR.RoleCode=URM.RoleCode
						inner join Orgs_Units O ON UR.UnitCode=O.UnitCode 
							where URM.RoleLetter='STTDCR' AND UnitLetter='TD'
							
			Union
			--  کد کاربری نمايندگان شوراي علمي را مي خواند
			select UPI.UserCode from Users_PersonalInfo UPI With(Nolock)
				inner join Users_Roles UR on UPI.UserCode=UR.UserCode
					inner join Users_Roles_Managment URM on UR.RoleCode=URM.RoleCode 
						inner join Orgs_Units O ON UR.UnitCode=O.UnitCode 
							where URM.RoleLetter='STTDSC' AND UnitLetter='TD'
						
		-- تا زمانی که در لیست کد کاربری وجود دارداز بالاترين ركوردش مقادير را خوانده                 
		WHILE (SELECT COUNT(UserCode) FROM @REceiveMailTemp ) <> 0  
		BEGIN
			SELECT TOP 1 @REceiveMailUsercode = UserCode FROM @REceiveMailTemp ORDER BY UserCode ASC
			
			--يوزكد داوران
			
			if(@REceiveMailUserTag Not like '%"'+cast(@REceiveMailUsercode as nvarchar(max))+'"%')--اگر اين يوزركد در ليست يوزرتگ وجود ندارد
			
				SET  @REceiveMailUserTag=  @REceiveMailUserTag + '<UserCode Value = "' + CONVERT(NVARCHAR(10),@REceiveMailUsercode) + '" />' 
			
			-- حذف داده استفاده شده از جدول تمپ
			DELETE FROM @REceiveMailTemp WHERE UserCode= @REceiveMailUsercode
			
		end
--========================================================================================================================	
	  SET @ReturnValue = 2 --انتقال به مرحله دوم گردش مصاحبه
	  SET @ErrorMessage = N''
	  SET @UserCodesXML =  '<UserRoot>'+
					       '	<UserCode Value="'+@managerCode+'" />'+
					       '</UserRoot>'-- گيرنده مرحله دوم: كاربر واحد فناور
	  SET @EmailXML=N'<EmailRoot>'+
				N'	<Email Text="  با سلام&lt;br&gt;&lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;احتراما به استحضار مي رساند فرم '
				+'&lt;font color=&quot;blue&quot;&gt;'
				+N' جلسه مصاحبه جهت پذيرش در پارک علم و فناوری  '+'&lt;/font&gt;'+N' در تاريخ '
				+@CurrentDate+N' ساعت '+@CurrentTime+
				N' در كارتابل جنابعالي قرار گرفته است.لطفا حداکثر تا 5 ساعت قبل از برگزاری جلسه فایل ارائه خود را بارگذاری نمایید. &lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;&lt;br&gt;با تشكر&lt;/p&gt;&lt;/p&gt;" >'
				+ N'<UserCode Value="'+@managerCode+'" />'+
				N'	</Email>'+--گيرنده ايميل: كاربر واحد فناور
				N'</EmailRoot>' 
	
		-------------شروع گردش تصاویر جلسه برای کارشناسان روابط عمومی و ارسال پیام برای زمان جلسه--------------
		
		DECLARE @Photographer_TEMP TABLE (UserCode INT)--جدول موقت نگهدارنده کد کارشناسان روابط عمومی
		DECLARE @PhotographerUserTag nvarchar(max)=''--كد كاربري کارشناسان
		DECLARE @PhotographerUsercode nvarchar(max)='' ---كد كاربري کارشناس
		
		INSERT INTO @Photographer_TEMP	
			SELECT DISTINCT UR.UserCode FROM Users_Roles UR INNER JOIN Users_Roles_Managment RM
			ON UR.RoleCode=RM.RoleCode WHERE RoleLetter='GRAVEX'--'STGREX'--كارشناس امور عكاسي
		
		-- تا زمانی که در لیست کد کاربری وجود دارداز بالاترين ركوردش مقادير را خوانده                 
		WHILE (SELECT COUNT(UserCode) FROM @Photographer_TEMP ) <> 0  
		BEGIN
			SELECT TOP 1 @PhotographerUsercode = UserCode FROM @Photographer_TEMP ORDER BY UserCode ASC
			
			--يوزكد کارشناسان روابط عمومی
			
			if(@PhotographerUserTag Not like '%"'+cast(@PhotographerUsercode as nvarchar(max))+'"%')--اگر اين يوزركد در ليست يوزرتگ وجود ندارد
			
				SET  @PhotographerUserTag=  @PhotographerUserTag + '<UserCode Value = "' + CONVERT(NVARCHAR(10),@PhotographerUsercode) + '" />' 
			
			-- حذف داده استفاده شده از جدول تمپ
			DELETE FROM @Photographer_TEMP WHERE UserCode= @PhotographerUsercode
			
		end
		
		DECLARE @ُSuspend VARCHAR(20)--كد كاربر معلق
		=(SELECT DISTINCT UR.UserCode FROM Users_Roles UR 
		INNER JOIN Users_Roles_Managment RM ON RM.RoleCode = UR.RoleCode WHERE RM.RoleLetter = 'SUSPEND')
		-----------------------------------------------------------------------------------------------------
			 			
		SET @SMSXML = N'<SMSRoot>'+
					N'	<SMS Text="احتراما به اطلاع مي رساند جلسه مصاحبه واحد فناور « '+@CompanyName
					+N' » جهت پذيرش در پارک علم و فناوری در تاريخ '+@SeminarDate +N' ساعت '+Cast(@SeminarHour as nvarchar(100)) 
					+N':'+Cast(@SeminarMinute as nvarchar(100))+N' در « '+@SeminarPlace
					+N' » برگزار مي گردد. لازم به ذکر است حداکثر تا 5 ساعت قبل از برگرازی جلسه، فایل ارائه خود را بارگذاری نمایید." >'+
					N'		<UserCode Value="'+@managerCode+'" />'+ --گيرنده: كاربر واحد فناور
					N'	</SMS>'+
					-------------------------عکاس روابط عمومی--------------------------------
					N'	<SMS Text="احتراما به اطلاع مي رساند جلسه مصاحبه واحد فناور « '+@CompanyName
					+N' » جهت پذيرش در پارک علم و فناوری در تاريخ '+@SeminarDate +N' ساعت '+Cast(@SeminarHour as nvarchar(100)) 
					+N':'+Cast(@SeminarMinute as nvarchar(100))+N' در « '+@SeminarPlace+N' » برگزار مي گردد." >'+
					@PhotographerUserTag+ --گيرنده: کارشناسان روابط عمومی
					N'	</SMS>'+
					N'</SMSRoot>'
					
	  --SET @SMSXML = N'<SMSRoot>'+
			--				N'	<SMS Text="احتراما به اطلاع مي رساند جلسه مصاحبه جهت پذيرش واحد فناوري '
			--				+@CompanyName+N' در تاريخ '+@SeminarDate +N' ساعت '+Cast(@SeminarHour as nvarchar(100)) +N':'
			--				+Cast(@SeminarMinute as nvarchar(100))+
			--				N' در محل '+@SeminarPlace+N' برگزار مي گردد.لطفا حداکثر تا 5 ساعت قبل از برگزاری جلسه فایل ارائه خود را بارگذاری نمایید'+'" >'+
			--				N'		<UserCode Value="'+@managerCode+'" />'+ --گيرنده: كاربر واحد فناور
			--				N'	</SMS>'+
			--				N'</SMSRoot>'
							
	  SET @MessageXML =N''
	  SET @ExtraOutputXML = 
					N'<ExtraOuts>'+
					N'<ExtOut ReturnValue="1" ErrorMessage="''" >'+ --شروع مرحله اول گردش ارزيابي در مركز پارک
					N'<UserRoot>'+@UserTag+N'</UserRoot>'+
					CONVERT (NVARCHAR(max), @EmailXMLTEMP)+  --گيرنده ايميل: شروع كنندگان گردش ارزيابي
					CONVERT (NVARCHAR(max), @SMSXMLTEMP)+    --گيرنده پيام كوتاه: شروع كنندگان گردش ارزيابي 
					--CONVERT (NVARCHAR(max), @MessageXMLTEMP)+ --گيرنده پيام پورتال:اعضاي شوراي پذيرش جهت داوري
					N'<MessageRoot>'+
					N'<Message Text="" >'+
					N'<UserCode Value="" />'+
					N'</Message>'+
					N'</MessageRoot>'+
					N'</ExtOut>'+
							----------------------------------------------
					N'<ExtOut ReturnValue="8" ErrorMessage="" >'+--شروع مرحله اول گردش نامه هاي دريافتي
					N'<UserRoot>'+ @REceiveMailUserTag +'</UserRoot>'+ --داوران و مدیران واحد فناوری
					N'<EmailRoot>'+
					N'<Email Text="" >'+
					N'<UserCode Value="" />'+
					N'</Email>'+--گيرنده ايميل: داوران و مدیران واحد فناوری
					N'</EmailRoot>' +
					N'<SMSRoot>'+
					N'<SMS Text="" >'+
					N'<UserCode Value="" />'+
					N'</SMS>'+
					N'</SMSRoot>'+
					N'<MessageRoot>'+
					N'<Message Text="" >'+
					N'<UserCode Value="" />'+
					N'</Message>'+
					N'</MessageRoot>'+
					N'</ExtOut>'+
					----------------------------------------------------------------------------------
					N'<ExtOut ReturnValue="-1" ErrorMessage="N''" >'+ --شروع گردش تصاویر جلسه مصاحبه
					N'<UserRoot>'+
					N'<UserCode Value="'+@ُSuspend+'" />'+
					N'</UserRoot>'+
					N'<EmailRoot>'+
					N'<Email Text="" >'+
					N'<UserCode Value="" />'+			
					N'</Email>'+	
					N'</EmailRoot>'+
					N'<SMSRoot>'+
					N'<SMS Text="" >'+
					N'<UserCode Value="" />'+
					N'</SMS>'+
					N'</SMSRoot>'+
					N'<MessageRoot>'+
					N'<Message Text="" >'+
					N'<UserCode Value="" />'+
					N'</Message>'+
					N'</MessageRoot>'+
					N'</ExtOut>'+		
					N'</ExtraOuts>'			
					
	
 END
		
--	======================================مرحله بارگذاری فایل سمینار=========================================	
	
    IF (@StateLetter=N'RERC14S02') --statecode=106                     
	  Begin	 	 
		  SET @ReturnValue = 3 --مرحله بعد: مرحله سوم
		  SET @ErrorMessage = N''
		  SET @UserCodesXML ='<UserRoot>'+
						     '	<UserCode Value="'+CONVERT (NVARCHAR(max),@Master_Expert)+'" />'+
						     '</UserRoot>'-- گيرنده مرحله سوم: سرپرست پذيرش
	      SET @EmailXML=N'' 
		  SET @SMSXML = N''
		  SET @MessageXML = N''
		  SET @ExtraOutputXML =N'' 
	  END
	
--	======================================مرحله بررسی سرپرست پذیرش/انتخاب جمع بندی کننده=========================================	
    IF @StateLetter IN ('RERC14S03','RERC14S05') --statecode=107 
    	BEGIN
		
		IF @SupervisorResult='Confirm'--در صورت تأیید سرپرست ارسال به مرحله بررسی فرمهای ارزیابی
		BEGIN
			SET @ReturnValue = 8
			SET @ErrorMessage = N''
			
			IF @ResponsibleSelection='AdmissionsSupervisor'
		
				SET @UserCodesXML = '<UserRoot>'+
									'	<UserCode Value="' + CONVERT(NVARCHAR,@Master_Expert) + '" />'+
									'</UserRoot>'-- گيرنده مرحله هشتم: سرپرست پذيرش
		
			ELSE IF @ResponsibleSelection='ExpertAdmission'
		
				SET @UserCodesXML = '<UserRoot>'+
									'	<UserCode Value="' + CONVERT(NVARCHAR,@ResponsibleExpert) + '" />'+
									'</UserRoot>'-- گيرنده مرحله هشتم: کارشناس پذيرش
			SET @EmailXML = N''
			SET @SMSXML = N''
			SET @MessageXML = N''
			SET @ExtraOutputXML = N'' 
		END
		
		ELSE IF @SupervisorResult='Disconfirmation'--در صورت عدم تأیید سرپرست ارسال به مرحله اصلاح پس از بررسی سرپرست پذیرش
		BEGIN
			SET @ReturnValue = 6
			SET @ErrorMessage = N''
			SET @UserCodesXML = '<UserRoot>'+
								'	<UserCode Value="' + CONVERT(NVARCHAR,@managerCode) + '" />'+
								'</UserRoot>'-- گيرنده مرحله ششم: مدیر واحد
								
			SET @EmailXML=N'<EmailRoot>'+
				N'	<Email Text="  با سلام&lt;br&gt;&lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;احتراما به استحضار مي رساند فرم '
				+'&lt;font color=&quot;blue&quot;&gt;'
				+N' جلسه مصاحبه جهت پذيرش در پارک علم و فناوری  '+'&lt;/font&gt;'+N' در تاريخ '
				+@CurrentDate+N' ساعت '+@CurrentTime+
				N' در كارتابل جنابعالي قرار گرفته است.لطفا حداکثر تا 5 ساعت قبل از برگزاری جلسه فایل ارائه خود را بارگذاری نمایید. &lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;&lt;br&gt;با تشكر&lt;/p&gt;&lt;/p&gt;" >'
				+ N'<UserCode Value="'+@managerCode+'" />'+
				N'	</Email>'+--گيرنده ايميل: كاربر واحد فناور
				N'</EmailRoot>' 
			
			SET @SMSXML = N''
			SET @MessageXML = N''
			SET @ExtraOutputXML = N''
		END
		ELSE IF @SupervisorResult='Expert'--در صورت ارجاع به کارشناس توسط سرپرست ارسال به مرحله بررسی توسط کارشناس پذیرش
		BEGIN
			SET @ReturnValue = 4
			SET @ErrorMessage = N''
			SET @UserCodesXML = '<UserRoot>'+
								'	<UserCode Value="' + CONVERT(NVARCHAR,@FileExpert) + '" />'+
								'</UserRoot>'-- گيرنده مرحله چهارم: کارشناس پذيرش		
			SET @EmailXML = N''
			SET @SMSXML = N''
			SET @MessageXML = N''
			SET @ExtraOutputXML = N'' 
		END
	
	END
   
--	======================================مرحله بررسی کارشناس پذیرش=========================================	
	IF @StateLetter = 'RERC14S04'   
	BEGIN
		IF @ExpertResult='Confirm'--در صورت تأیید کارشناس ارسال به مرحله انتخاب جمع بندی کننده
		BEGIN	
			SET @ReturnValue = 5
		    SET @ErrorMessage = N''
			SET @UserCodesXML = '<UserRoot>'+
								'	<UserCode Value="' + CONVERT(NVARCHAR,@Master_Expert) + '" />'+
								'</UserRoot>'-- گيرنده مرحله پنجم: سرپرست پذيرش
			SET @EmailXML = N''
			SET @SMSXML = N''
			SET @MessageXML = N''
			SET @ExtraOutputXML = N'' 
		END
		
		ELSE IF @ExpertResult='Disconfirmation'--در صورت عدم تأیید کارشاس ارسال به مرحله اصلاح پس از بررسی کارشناس پذیرش
		BEGIN
			SET @ReturnValue = 7
			SET @ErrorMessage = N''
			SET @UserCodesXML = '<UserRoot>'+
								'	<UserCode Value="' + CONVERT(NVARCHAR,@managerCode) + '" />'+
								'</UserRoot>'-- گيرنده مرحله هفتم: مدیر واحد
			SET @EmailXML=N'<EmailRoot>'+
				N'	<Email Text="  با سلام&lt;br&gt;&lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;احتراما به استحضار مي رساند فرم '
				+'&lt;font color=&quot;blue&quot;&gt;'
				+N' جلسه مصاحبه جهت پذيرش در پارک علم و فناوری  '+'&lt;/font&gt;'+N' در تاريخ '
				+@CurrentDate+N' ساعت '+@CurrentTime+
				N' در كارتابل جنابعالي قرار گرفته است.لطفا حداکثر تا 5 ساعت قبل از برگزاری جلسه فایل ارائه خود را بارگذاری نمایید. &lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;&lt;br&gt;با تشكر&lt;/p&gt;&lt;/p&gt;" >'
				+ N'<UserCode Value="'+@managerCode+'" />'+
				N'	</Email>'+--گيرنده ايميل: كاربر واحد فناور
				N'</EmailRoot>' 
				
			SET @SMSXML = N''
			SET @MessageXML = N''
			SET @ExtraOutputXML = N''
		END
		
	
	END
  --  IF (@StateLetter=N'RERC14S03') --statecode=107 
  --     BEGIN
             	
  --     	IF (@EvaluationFormsConclusion=1)
		---- حذف فرم های ارزيابي از كارتابل داوران و غیره 
		-- --اتمام گردشهاي ارزيابي با تابع
  --        EXEC Gen_AutoFinishWF @MDTC= @DTC_ParkSeminar , @MDC= @DocumentCode ,@MWFLetter='RERC14' , @WFLetter='RERC16'         
          
	 --          SET @ReturnValue = 4 --اتمام فرآيند
		--       SET @ErrorMessage = N''
		--       SET @UserCodesXML = N''
		--       SET @EmailXML=N''
		--       SET @SMSXML = N''
		--       SET @MessageXML = N''
		--       SET @ExtraOutputXML =N''
	 --     END 

--	======================================مرحله اصلاح پس از بررسی سرپرست=========================================	
	IF @StateLetter='RERC14S06'
	BEGIN

		--در صورتیکه از مرحله انتخاب جمع بندی کننده آمده باشد
		 IF 'RERC14S05' IN (SELECT TOP 1 WS.StateLetter FROM  wfd_WorkflowsStates WS  
			INNER JOIN wfi_StateInstances WSI ON WSI.StateCode=WS.StateCode
				INNER JOIN wfi_WorkflowInstances WI ON WSI.WFInstanceCode= WI.WFInstanceCode 
					INNER JOIN wfi_PoolInstances PIN ON WI.PoolInstanceCode= PIN.PoolInstanceCode
						INNER JOIN wfd_Workflows W ON WI.WorkflowCode=W.WorkflowCode  
							WHERE PIN.CompileDC= @DocumentCode AND PIN.DTC= @DTC_ParkSeminar
								and WorkflowLetter='RERC14' AND WSI.STFinished=1
									ORDER BY WSI.STFinishDate DESC)
		BEGIN
			SET @ReturnValue = 5--انتقال به مرحله انتخاب جمع بندی کننده
			SET @ErrorMessage = N''
			SET @UserCodesXML = '<UserRoot>'+
								'<UserCode Value="'+CONVERT(NVARCHAR,@Master_Expert) +'" />'+
								'</UserRoot>' 
		END

    ELSE 	----در صورتیکه از مرحله بررسی سرپرست آمده باشد
 
		  BEGIN
			SET @ReturnValue = 3--انتقال به مرحله بررسی سرپرست پذیرش
			SET @ErrorMessage = N''
			SET @UserCodesXML = '<UserRoot>'+
								'<UserCode Value="'+CONVERT(NVARCHAR,@Master_Expert) +'" />'+
								'</UserRoot>' 
		  END
		  
		SET @EmailXML = N''
		SET @SMSXML = N''
		SET @MessageXML = N''
		SET @ExtraOutputXML = N'' 
	END
--	======================================اصلاح پس از بررسی کارشناس=========================================	
	IF @StateLetter='RERC14S07'
		BEGIN	
			SET @ReturnValue = 4 -- انتقال به مرحله بررسي كارشناس پذيرش								 
			SET @ErrorMessage = N''
			SET @UserCodesXML = '<UserRoot>'+
								'<UserCode Value="'+ CONVERT(NVARCHAR,@FileExpert) +'" />'+
								'</UserRoot>'
			SET @EmailXML = N''
			SET @SMSXML = N''
			SET @MessageXML = N''
			SET @ExtraOutputXML = N'' 
		END
		
------------------------------------------------------------------------------------------------------------    
    IF (@StateLetter=N'RERC14S08')  --statecode=86
       BEGIN
          --DECLARE @CountXML int--تعداد نفرات انتخاب شده
          DECLARE @SelectiveMemberTemp table(UserCode int)
          --DECLARE @UserCode int--یوزر کد نفرات انتخاب شده
          
           set arithabort on                   
			 Set @CountXML= @SelectiveMember.value('count(/Records/Record/@RowID)', 'int')
		 
			  while @CountXML<>'0'
		  
				  begin  
					set arithabort on
					set @UserCode= @SelectiveMember.value(N'(Records/Record/Field[@name="RERC14H03_SessionMembers"]/@Value)[1]','INT')
					
					--اگر اين يوزركد در جدول افراد انتخاب شده وجود ندارد
					if not exists (select UserCode from @SelectiveMemberTemp where usercode =@UserCode)
					 insert into @SelectiveMemberTemp 
					   select @UserCode
		            --select @UserTag = @UserTag+'<UserCode Value="'+CONVERT(nvarchar(10),@Usercode)+'" />'
					
					set arithabort on
					set @SelectiveMember.modify('delete /Records/Record [1]')
					set @CountXML=@CountXML-1
				  end
				  
       --انتخاب گزینه ی تکمیل فرم
       IF (@ExpertOpinion='FinishingExpert')
         BEGIN                  
         				  
             while (select COUNT(*) from @MemberTemp)>0
              begin
				 DECLARE @DTC INT --شماره جدول گردش ادامه دهنده
				 DECLARE @CompileDC INT --شماره رکورد گردش ادامه دهنده
				 select top 1 @UserCode=UserCode from @MemberTemp
	             
				 if exists (select usercode from @SelectiveMemberTemp where UserCode=@UserCode)
				  BEGIN
					  select top 1 @DTC=DTC  ,@CompileDC=CompileDC  from @MemberTemp
	       
					  --انتقال فرم های بازدید از كارتابل بازدیدکنندگان به کارتابل کارشناس
					  EXEC Gen_AutoFinishWF2 @DTC= @DTC , @DocumentCode= @CompileDC , 
						  @WFLetter='RERC17',@WFStateLetter='RERC17S01'					  

                  END 
		          
               DELETE from @MemberTemp WHERE @UserCode=UserCode
              end
              
             --اگر بیت ارسال اسمس خورده باشد
            IF(@SendingSms=1)
            BEGIN
            
            DECLARE @SMSTemp TABLE(Usercode INT)
            DECLARE @CountSMSTemp INT--تعداد ردیف های جدول
           ---------------------- 
            INSERT INTO @SMSTemp
             SELECT distinct UD.UserCode From wfi_UsersDashboards UD  
				 INNER JOIN wfi_WorkflowInstances WI ON UD.WFInstanceCode = WI.WFInstanceCode
				  INNER JOIN wfi_StateInstances SI ON SI.STInstanceCode = UD. STInstanceCode 
				   INNER JOIN wfd_WorkflowsStates WS ON WS.StateCode = SI.StateCode 
					  where WS.StateLetter IN('RERC17S01','RERC17S03') AND UD.Deleted = 0 and WI.PreviousWFInstanceCode= 
					   (select WFInstanceCode from wfi_WorkflowInstances WI with(Nolock)
						inner join wfi_PoolInstances P on P.PoolInstanceCode= WI.PoolInstanceCode 
						 inner join wfd_Workflows AS WF ON WF.WorkflowCode=WI.WorkflowCode
						   where CompileDC=@DocumentCode and DTC=@DTC_ParkSeminar and WF.WorkflowLetter ='RERC14') 
						   
				 EXCEPT
				 
				select UserCode from @SelectiveMemberTemp		   
            ---------------------- 
            SELECT @CountSMSTemp =COUNT(*) FROM @SMSTemp
            WHILE @CountSMSTemp<>'0'
				BEGIN 
				SELECT TOP 1 @UserCode=Usercode FROM @SMSTemp
				
				SELECT @SMSUserTag=@SMSUserTag+ '<UserCode Value="'+CONVERT (NVARCHAR(max),@UserCode)+'" />'
	            
	            DELETE FROM @SMSTemp WHERE Usercode=@UserCode
	            
	            SELECT @CountSMSTemp=@CountSMSTemp-1
				END
          END
          
          
               SET @ReturnValue = 8 --مرحله تصميم گيري براي جمع بندي فرم هاي ارزيابي سمینار
			   SET @ErrorMessage = N''
			
			   IF @ResponsibleSelection='AdmissionsSupervisor'		
				SET @UserCodesXML = '<UserRoot>'+
									'	<UserCode Value="' + CONVERT(NVARCHAR,@Master_Expert) + '" />'+
									'</UserRoot>'-- گيرنده مرحله هشتم: سرپرست پذيرش
		
			   ELSE IF @ResponsibleSelection='ExpertAdmission'		
				SET @UserCodesXML = '<UserRoot>'+
									'	<UserCode Value="' + CONVERT(NVARCHAR,@ResponsibleExpert) + '" />'+
									'</UserRoot>'-- گيرنده مرحله هشتم: کارشناس پذيرش
		       SET @EmailXML=N''
		       
		       IF @SMSUserTag=N''
		         SET @SMSXML = N''
		         
		       IF @SMSUserTag<>N''
		         SET @SMSXML = N'<SMSRoot>'+
					N'	<SMS Text="خواهشمند است نسبت به تکمیل فرم «ارزيابي پذيرش واحد فناوري در پارك علم و فناوري» مربوط به واحد فناور « '+@CompanyName+N' » اقدام نمایید" >'+
					@SMSUserTag+
					N'	</SMS>'+
					N'</SMSRoot>'
		         
		       SET @MessageXML = N''
		       SET @ExtraOutputXML = N''
        END
        
        
        ELSE IF (@ExpertOpinion='FormsConclusion')
         BEGIN 
        
             --اگر بیت ارسال اسمس خورده باشد
            IF(@SendingSms=1)
            BEGIN
            
            --DECLARE @SMSTemp TABLE(Usercode INT)
            --DECLARE @CountSMSTemp INT--تعداد ردیف های جدول
           ---------------------- 
            INSERT INTO @SMSTemp
             SELECT distinct UD.UserCode From wfi_UsersDashboards UD  
				 INNER JOIN wfi_WorkflowInstances WI ON UD.WFInstanceCode = WI.WFInstanceCode
				  INNER JOIN wfi_StateInstances SI ON SI.STInstanceCode = UD. STInstanceCode 
				   INNER JOIN wfd_WorkflowsStates WS ON WS.StateCode = SI.StateCode 
					  where WS.StateLetter IN('RERC17S01','RERC17S03') AND UD.Deleted = 0 and WI.PreviousWFInstanceCode= 
					   (select WFInstanceCode from wfi_WorkflowInstances WI with(Nolock)
						inner join wfi_PoolInstances P on P.PoolInstanceCode= WI.PoolInstanceCode 
						 inner join wfd_Workflows AS WF ON WF.WorkflowCode=WI.WorkflowCode
						   where CompileDC=@DocumentCode and DTC=@DTC_ParkSeminar and WF.WorkflowLetter ='RERC14') 	   
            ---------------------- 
            SELECT @CountSMSTemp =COUNT(*) FROM @SMSTemp
            WHILE @CountSMSTemp<>'0'
				BEGIN 
				SELECT TOP 1 @UserCode=Usercode FROM @SMSTemp
				
				SELECT @SMSUserTag=@SMSUserTag+ '<UserCode Value="'+CONVERT (NVARCHAR(max),@UserCode)+'" />'
	            
	            DELETE FROM @SMSTemp WHERE Usercode=@UserCode
	            
	            SELECT @CountSMSTemp=@CountSMSTemp-1
				END
          END 
         
        
               SET @ReturnValue = 9 --مرحله جمع بندي فرم هاي ارزيابي سمینار
		       SET @ErrorMessage = N''
		     --IF @ResponsibleSelection='AdmissionsSupervisor'
		
				SET @UserCodesXML = '<UserRoot>'+
									'	<UserCode Value="' + CONVERT(NVARCHAR,@Master_Expert) + '" />'+
									'</UserRoot>'-- گيرنده مرحله هشتم: سرپرست پذيرش
		
			 --ELSE IF @ResponsibleSelection='ExpertAdmission'
		
				--SET @UserCodesXML = '<UserRoot>'+
				--					'	<UserCode Value="' + CONVERT(NVARCHAR,@ResponsibleExpert) + '" />'+
				--					'</UserRoot>'-- گيرنده مرحله هشتم: کارشناس پذيرش
		       SET @EmailXML=N''
		       
		       IF @SMSUserTag=N''
		         SET @SMSXML = N''
		         
		       IF @SMSUserTag<>N''
		         SET @SMSXML = N'<SMSRoot>'+
					N'	<SMS Text="خواهشمند است نسبت به تکمیل فرم «ارزيابي پذيرش واحد فناوري در پارك علم و فناوري» مربوط به واحد فناور « '+@CompanyName+N' » اقدام نمایید" >'+
					@SMSUserTag+
					N'	</SMS>'+
					N'</SMSRoot>'
		         
		       SET @MessageXML = N''
		       SET @ExtraOutputXML = N''
         END
         
     ELSE IF @ExpertOpinion='None' AND @SendingSms=1   
          BEGIN
     --        INSERT INTO @SMSTemp
     --        SELECT distinct UD.UserCode From wfi_UsersDashboards UD  
				 --INNER JOIN wfi_WorkflowInstances WI ON UD.WFInstanceCode = WI.WFInstanceCode
				 -- INNER JOIN wfi_StateInstances SI ON SI.STInstanceCode = UD. STInstanceCode 
				 --  INNER JOIN wfd_WorkflowsStates WS ON WS.StateCode = SI.StateCode 
					--  where WS.StateLetter IN('RERC17S01','RERC17S03') AND UD.Deleted = 0 and WI.PreviousWFInstanceCode= 
					--   (select WFInstanceCode from wfi_WorkflowInstances WI with(Nolock)
					--	inner join wfi_PoolInstances P on P.PoolInstanceCode= WI.PoolInstanceCode 
					--	 inner join wfd_Workflows AS WF ON WF.WorkflowCode=WI.WorkflowCode
					--	   where CompileDC=@DocumentCode and DTC=@DTC_ParkSeminar and WF.WorkflowLetter ='RERC14') 	   
              ---------------------- 
              SELECT @CountSMSTemp =COUNT(*) FROM @SelectiveMemberTemp
              WHILE @CountSMSTemp<>'0'
					BEGIN 
					SELECT TOP 1 @UserCode=Usercode FROM @SelectiveMemberTemp
					
					SELECT @SMSUserTag=@SMSUserTag+ '<UserCode Value="'+CONVERT (NVARCHAR(max),@UserCode)+'" />'
		            
					DELETE FROM @SelectiveMemberTemp WHERE Usercode=@UserCode
		            
		            SELECT @CountSMSTemp =@CountSMSTemp-1
					END         
        
               SET @ReturnValue = 8 --مرحله تصميم گيري براي جمع بندي فرم هاي ارزيابي سمینار
		       SET @ErrorMessage = N''
		    IF @ResponsibleSelection='AdmissionsSupervisor'
		
				SET @UserCodesXML = '<UserRoot>'+
									'	<UserCode Value="' + CONVERT(NVARCHAR,@Master_Expert) + '" />'+
									'</UserRoot>'-- گيرنده مرحله هشتم: سرپرست پذيرش
		
			ELSE IF @ResponsibleSelection='ExpertAdmission'
		
				SET @UserCodesXML = '<UserRoot>'+
									'	<UserCode Value="' + CONVERT(NVARCHAR,@ResponsibleExpert) + '" />'+
									'</UserRoot>'-- گيرنده مرحله هشتم: کارشناس پذيرش
		       SET @EmailXML=N''		      
		       SET @SMSXML = N'<SMSRoot>'+
					N'	<SMS Text="خواهشمند است نسبت به تکمیل فرم «ارزيابي پذيرش واحد فناوري در پارك علم و فناوري» مربوط به واحد فناور « '+@CompanyName+N' » اقدام نمایید" >'+
					@SMSUserTag+
					N'	</SMS>'+
					N'</SMSRoot>'
		         
		       SET @MessageXML = N''
		       SET @ExtraOutputXML = N''
                
          END
   END
 --	======================================جمع بندی فرم های ارزیابی=========================================	
	IF @StateLetter='RERC14S09'
	BEGIN
	   --حذف فرم های ارزیابی از كارتابل اعضای جلسه
       EXEC Gen_AutoFinishWF @MDTC=@DTC_ParkSeminar,@MDC=@DocumentCode,@MWFLetter='RERC14',@WFLetter='RERC17'
       
       --آپديت وضعيت سمينار اين واحد فناور
		--فعال مي شود
       UPDATE WSI_RERC_ParkSeminar_Compile SET RERC14H03_Active=1 WHERE DocumentCode=@DocumentCode
       
       SET @ReturnValue = 10 --اتمام فرآيند
	   SET @ErrorMessage = N''
	   SET @UserCodesXML = '<UserRoot><UserCode Value="-1" /></UserRoot>'
	   SET @EmailXML = N''
	   SET @SMSXML = N''
	   SET @MessageXML = N''
	   SET @ExtraOutputXML = N'' 
	END  
END
-------------------------------------------------------تنظیمات پرونده------------------------------------------------				
--در صورتي كه گردش تمام شده باشد
	if @ReturnValue IN(10,11)
	begin
	
		DECLARE @CO_AdmissionFolderLetter nvarchar(20)= Convert(nvarchar(10), @CompanyCode)+'RE'--كد زير پرونده پذيرش در پرونده واحد فناور
				
		DECLARE @CO_AdmissionFolderName  nvarchar(200)=N'پذيرش' --نام زير پرونده پذيرش در پرونده واحد فناور
		
		DECLARE @CO_FolderLetter VARCHAR(20)=Convert(nvarchar(10), @CompanyCode)+'CI'
		
		-- كد نقش كارشناس پذيرش
		DECLARE @TDREEXRoleCode NVARCHAR(10) = (SELECT RoleCode FROM Users_Roles_Managment WHERE RoleLetter = 'TDREEX')
		
		-- كد نقش سرپرست پذيرش
		DECLARE @TDREMARoleCode NVARCHAR(10) = (SELECT RoleCode FROM Users_Roles_Managment WHERE RoleLetter = 'TDREMA')
		
		-- كد نقش كارشناس ارشد پذيرش
		DECLARE @TDREMERoleCode NVARCHAR(10) = (SELECT RoleCode FROM Users_Roles_Managment WHERE RoleLetter = 'TDREME')
	
		DECLARE @UnitCode NVARCHAR(10) -- كد واحد سازماني	
		=(SELECT UnitCode FROM Orgs_Units WHERE UnitLetter = 'RE')
	
		DECLARE @REPermissionXML XML -- براي مجوز دسترسي هاي پرونده پذيرش
	
		SET @REPermissionXML='<Permissions>'+
								'<Permission RowID = "1" RoleCode = "'+@TDREEXRoleCode+'" UnitCode = "'+@UnitCode+
									'" PermissionType = "1" />'+
								'<Permission RowID = "2" RoleCode = "'+@TDREMARoleCode+'" UnitCode = "'+@UnitCode+
									'" PermissionType = "1" />'+
								'<Permission RowID = "3" RoleCode = "'+@TDREMERoleCode+'" UnitCode = "'+@UnitCode+
									'" PermissionType = "1" />'+		
							'</Permissions>'
							
		--*****************ایجاد زیرپرونده رد شده در پرونده شرکت******************		
	IF @ReturnValue=11
	BEGIN
		DECLARE @ParentFolderLetter VARCHAR(20)=Convert(nvarchar(10), @CompanyCode)+'RJ'--کد زیرپرونده رد شده در پرونده واحد فناور
		DECLARE @ParentFolderCode INT --کد زیرپرونده رد شده در پرونده واحد فناور
		DECLARE @ParentFolderName NVARCHAR(10)=N'رد شده'
		
		EXEC  [dbo].[SP_GEN_ReturnFolderCode]   @FolderLetter = @ParentFolderLetter, 
		@FolderName = @ParentFolderName, @ParentFolderLetter = @CompanyCode , @FolderCode = @ParentFolderCode OUTPUT
		
		EXEC SP_GEN_AssignFolderPermissions @FolderCode = @ParentFolderCode, @PermissionXML = @REPermissionXML
		
		--*****************قرار دادن زیرپرونده اطلاعات شرکت در پرونده رد شده******************
		
		EXEC SP_GEN_CutFolder @FolderLetter=@CO_FolderLetter ,@ParentFolderLetter=@ParentFolderLetter
		,@Type=1 ,@NewLetter='RJ'
		
		--*****************قرار دادن زیرپرونده پذيرش در پرونده رد شده******************
		
		EXEC SP_GEN_CutFolder @FolderLetter=@CO_AdmissionFolderLetter ,@ParentFolderLetter=@ParentFolderLetter
		,@Type=1 ,@NewLetter='RJ'
	
		--**************حذف نقش های مدیر واحد فناور در حال پذیرش و کاربر متقاضی پذیرش**************
			
		DECLARE @RECOMA_RoleCode INT --کد نقش کاربر متقاضی
		DECLARE @RECOMA_USERCode INT --کد کاربر متقاضی
		DECLARE @STCOMA_RoleCode INT --کد نقش مدیر درحال پذیرش
		DECLARE @STCOMA_USERCode INT --کد نقش کاربر متقاضی
		DECLARE @CO_UnitCode INT --کد سازمان کاربر متقاضی
		
		DECLARE @RECOMA_GroupCode INT --کد گروه کاربران متقاضی
		=(SELECT GroupCode FROM Users_Groups WHERE GroupLetter='CORE')--7
		
		DECLARE @STCOMA_GroupCode INT --کد گروه مدیران درحال پذیرش
		=(SELECT GroupCode FROM Users_Groups WHERE GroupLetter='COMA')--31
		
		DECLARE @RECOEX_RoleCode INT --کد نقش کاربر عادی شهرک
		=(SELECT RoleCode FROM Users_Roles_Managment WHERE RoleLetter='RECOEX')--59
		
		DECLARE @RECOEX_GroupCode INT --کد گروه کاربران عادی شهرک
		=(SELECT GroupCode FROM Users_Groups WHERE GroupLetter='OORE')--33
		
		SELECT @RECOMA_USERCode=TDOO26H01_CreatingUserCode,@RECOMA_RoleCode=U.RoleCode
		FROM WSI_TDOO_Company C INNER JOIN Users_Roles U ON C.TDOO26H01_ManagerUsercode=U.UserCode
		INNER JOIN Users_Roles_Managment RM ON U.RoleCode=RM.RoleCode
		WHERE DocumentCode=@CompanyCode AND RoleLetter='RECOMA'
		
		SELECT @STCOMA_USERCode=TDOO26H01_ManagerUsercode,@STCOMA_RoleCode=U.RoleCode,@CO_UnitCode=O.UnitCode 
		FROM WSI_TDOO_Company C INNER JOIN Users_Roles U ON C.TDOO26H01_ManagerUsercode=U.UserCode
		INNER JOIN Orgs_Units O ON U.UnitCode=O.UnitCode
		INNER JOIN Users_Roles_Managment RM ON U.RoleCode=RM.RoleCode
		WHERE DocumentCode=@CompanyCode AND RoleLetter='STCOMA' AND UnitLetter='CO'
		
		--حذف نقش
		EXEC dbo.sp_Users_DeleteRoles @UserCode=@RECOMA_USERCode,@RoleCode=@RECOMA_RoleCode,@UnitCode=@CO_UnitCode	
		EXEC dbo.sp_Users_DeleteRoles @UserCode=@STCOMA_USERCode,@RoleCode=@STCOMA_RoleCode,@UnitCode=@CO_UnitCode	
		
		--حذف از گروه
		EXEC dbo.User_Group_Delete @UserCode=@RECOMA_USERCode,@GroupCode=@RECOMA_GroupCode
		EXEC dbo.User_Group_Delete @UserCode=@STCOMA_USERCode,@GroupCode=@STCOMA_GroupCode
		
		--دادن نقش کاربر عادی شهرک
		EXEC dbo.sp_Users_AddRolesGroups @UserCode=@RECOMA_USERCode,@RoleCode=@RECOEX_RoleCode
		,@UnitCode=@CO_UnitCode,@GroupCode=@RECOEX_GroupCode
		
		EXEC dbo.sp_Users_AddRolesGroups @UserCode=@STCOMA_USERCode,@RoleCode=@RECOEX_RoleCode
		,@UnitCode=@CO_UnitCode,@GroupCode=@RECOEX_GroupCode
	END
	
		--***************قرار دادن فرم جلسه مصاحبه پارک  در پرونده پذيرش سال جاري واحد فناور******************
		if @ReturnValue=10 
	    begin	
		DECLARE @AssignCode INT -- خروجي پروسيجر قراردادن فرم در پرونده
		DECLARE @Comment NVARCHAR(MAX) -- اسم فرم در پرونده			
		DECLARE @FolderCode INT -- كد پرونده پذیرش سال جاری
		DECLARE @CurrentYear NVARCHAR(2)=SUBSTRING(@CurrentDate ,3 ,2) -- سال جاري
		DECLARE @FolderLetter NVARCHAR(50)='RE' + @CurrentYear -- كد پرونده پذیرش سال جاری
		DECLARE @FolderName NVARCHAR(100)= N'سال ' + @CurrentYear -- نام پرونده سال پذيرش
		

		EXEC  [dbo].[SP_GEN_ReturnFolderCode]   @FolderLetter = @FolderLetter, 
		@FolderName = @FolderName, @ParentFolderLetter = 'RE' , @FolderCode = @FolderCode OUTPUT
							   
		EXEC SP_GEN_AssignFolderPermissions @FolderCode = @FolderCode, @PermissionXML = @REPermissionXML	
		
		-----پرونده شركت زير پذيرش سال 
		DECLARE @Admission_FolderLetter nvarchar(20)= @FolderLetter+Convert(nvarchar(10), @CompanyCode)
		DECLARE @Admission_FolderCode int
		DECLARE @Admission_FolderName  nvarchar(200)=@CompanyName
		
		EXEC  [dbo].[SP_GEN_ReturnFolderCode]   @FolderLetter = @Admission_FolderLetter, 
		@FolderName = @Admission_FolderName, @ParentFolderLetter = @FolderLetter , @FolderCode = @Admission_FolderCode OUTPUT
				   
		EXEC SP_GEN_AssignFolderPermissions @FolderCode = @Admission_FolderCode, @PermissionXML = @REPermissionXML	
			
		SET @Comment = N'جلسه مصاحبه جهت پذيرش در پارك علم و فناوري، ' + @CompanyName

		if Not exists (Select * from wfd_FolderContain where FolderCode=@Admission_FolderCode and DTC=@DTC_ParkSeminar and DC=@DocumentCode
			and Comment=@Comment and IsCompile=1)
			
		EXEC [dbo].[sp_DocsFolderAssign] @Admission_FolderCode, @DTC_ParkSeminar, @DocumentCode , @Comment , 1 , @AssignCode OUTPUT
		
	    end	
		--***************قرار دادن فرم جلسه مصاحبه پارک در زير پرونده پذيرش پرونده واحد فناور******************
		
		DECLARE @CO_AdmissionFolderCode INT--كد پرونده پذيرش واحد فناور
		=(SELECT FolderCode FROM wfd_FolderCategory WHERE FolderLetter=@CO_AdmissionFolderLetter)
		
		if Not exists (Select * from wfd_FolderContain where FolderCode=@CO_AdmissionFolderCode and DTC=@DTC_ParkSeminar and DC=@DocumentCode
			and Comment=@Comment and IsCompile=1)
			
	    EXEC [dbo].[sp_DocsFolderAssign] @CO_AdmissionFolderCode, @DTC_ParkSeminar, @DocumentCode , @Comment , 1 , @AssignCode OUTPUT  	   
			
	end--end return
	


END