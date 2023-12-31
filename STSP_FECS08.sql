USE [DigitalLibrary]
GO
/****** Object:  StoredProcedure [dbo].[STSP_FECS08]    Script Date: 07/03/2017 10:04:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Hale Kavoosi>
-- Create date: <07/03/2017>
-- Description:	<پروسیجر بررسی شروط انتقال گردش کار طرح كسب و كار آزاد>
-- =============================================

ALTER PROCEDURE  [dbo].[STSP_FECS08]
	
	@DocumentCode INT,
	@StateCode INT,
	@ReturnValue INT = -1000 OUT ,				--مقدار اصلی خروجی روال
	@ErrorMessage NVARCHAR(512) =N'' OUT,		-- پیام برای نمایش در کارتابل
	@UserCodesXML NVARCHAR(4000) =N'' OUT,		-- انجام دهنگان مرحله بعدی
	@EmailXML NVARCHAR(4000) =N'' OUT,			--کاربران دریافت کننده ایمیل و متن آنها
	@SMSXML NVARCHAR(4000) =N'' OUT,			--کاربران دریافت کننده پیامک و متن آنها
	@MessageXML NVARCHAR(4000) =N'' OUT	,		--کاربران دریافت کننده پيام و متن آنها
	@ExtraOutputXML nvarchar(4000) = '' OUT		--برای خروج های اضافی با فرمت مشخص

	AS
	BEGIN

		DECLARE @StateLetter NVARCHAR (30)    -- کد مرحله جاری
		DECLARE @CurrentDate datetime    -- تاريخ جاری      
		DECLARE @SecretariatExpCode NVARCHAR (30)  -- کد يوزر کارشناس دبيرخانه جشنواره
		DECLARE @CreatingUserCode NVARCHAR (445) --كد كاربر ايجاد كننده
		DECLARE @FormCompeleteName NVARCHAR (445) --نام تكميل كننده فرم
		DECLARE @PlanTitle NVARCHAR (445) --عنوان طرح
	    DECLARE @FestivalNo NVARCHAR (445) --شماره جشنواره
	    DECLARE @FestivalPr NVARCHAR (445) --دوره جشنواره
        DECLARE @SubAgentCode nvarchar(max) --كد زيرعامل
        DECLARE @ResidenceState nvarchar(max)=''--استان محل اقامت
        DECLARE @ExpertCheckResult nvarchar(max) =''--نتيجه بررسي طرح توسط كارشناس عامل 
        DECLARE @SecretariatCheckResult nvarchar(max) =''--نتيجه بررسي طرح توسط دبيرخانه 
        DECLARE @FormRejectionResult nvarchar(max) =''--علت رد طرح 
        DECLARE @ManagerResultCheck nvarchar(max) =''--نتيجه بررسي داوري هاي انجام شده توسط مديرعامل 
        DECLARE @AgentCode nvarchar(max)=''--کد عامل      
        DECLARE @AgentName nvarchar(max)=''--نام عامل        
        DECLARE @AgentCodeExp nvarchar(max)=''--کد كارشناس عامل
        DECLARE @AgentCodeMGMT nvarchar(max)=''--کد مدير عامل
        DECLARE @SubAgentCodeMGMT nvarchar(max)=''--کد مدير زيرعامل
        DECLARE @AutoFinishTask nvarchar(max)=''--تسكي كه در مرحله ي جاري به شكل اتوماتيك تمام شده است 
        DECLARE @SummeryRegistrationEndDate date --تاریخ اتمام طرح های تکمیل نشده
        DECLARE @RegistrationDeadline date --مهلت ثبت نام 
        DECLARE @CheckDate nvarchar(max)  --تاریخ بررسی کارشناس عامل
        DECLARE @DTC_BusinessPlanArbiteration INT--کد جدول داوري طرح كسب و كار
        DECLARE @Dissuasion bit --درخواست انصراف
	    DECLARE @PaymentConfirm BIT --بیت تایید پرداخت
		DECLARE @Festival_UserCode INT        -- کد يوزر بررسي دبيرخانه جشنواره

	SELECT
		@CreatingUserCode=FECS08H01_CreatingUserCode
		,@FormCompeleteName=FECS08H01_CreatingUsserName
		,@PlanTitle=FECS08H01_PlanTitle
		,@FestivalNo=FECS08H01_FestivalNo
		,@ExpertCheckResult= FECS08H02_ExpertCheckResult
		,@SubAgentCode= FECS08H02_SubAgentDesignated
		,@SecretariatCheckResult=FECS08H02_SecretariatCheckResult
		,@FormRejectionResult=FECS08H02_FormRejectionResult
		,@ManagerResultCheck=FECS08H04_ManagerResultCheck
		,@AgentCodeExp=FECS08H02_AgentExpertCode
		,@AgentCode=FECS08H02_AgentCode	
		,@CheckDate=[dbo].[PersianToGregorian](FECS08H02_CheckDate)
		,@SecretariatExpCode=FECS08H02_SecretariatExpCode
		,@AgentName=FECS08H02_AgentName	
	    ,@Dissuasion=FECS08H01_RegisterCancel
	    ,@ResidenceState=FECS08H01_ResidenceState
	    ,@PaymentConfirm=FECS08H01_PaymentConfirm

		
	     FROM CMSI_FECS_BusinessPlan_Compile WHERE DocumentCode = @DocumentCode
	
		SET @ErrorMessage = N'لطفا به موارد زير توجه نماييد '	

--**********************************************************************************************
--بازیابی اطلاعات از تعریف جشنواره
		 SELECT @SummeryRegistrationEndDate=LEFT(FECS01H01_SummeryRegistrationEndDate,11),
		 @RegistrationDeadline=LEFT(FECS01H01_RegistrationDeadline,11),
		 @FestivalPr=FECS01H01_FestivalPeriod
	    from CMSI_FECS_FestivalDefine_Compile WHERE FECS01H01_ActiveFes = 1
--------------------------------------------------------------------------------------		    
		--علت رد طرح
		IF @FormRejectionResult='Duplicate'
		    set @FormRejectionResult=N'تكراري بودن طرح'
		ELSE IF @FormRejectionResult='NonStandard'
		    set @FormRejectionResult=N'عدم مطابقت طرح با فرم استاندارد كسب و كار'
		-------------------------------------------------------------------------------------   	    
		DECLARE @BusinessPlan_DTC INT=(SELECT DocumentTypeCode FROM Docs_Infos WITH (NOLOCK) WHERE DocumentTypeName = 'CMSI_FECS_BusinessPlan')	
        select @DTC_BusinessPlanArbiteration= DocumentTypeCode from  docs_infos  WITH (NOLOCK) where DocumentTypeName='CMSI_FECS_BusinessPlanArbiteration'
		--DECLARE @BusinessPlan_DTC INT=(SELECT DocumentTypeCode FROM Docs_Infos WITH (NOLOCK) WHERE DocumentTypeName = 'CMSI_FECS_BusinessPlan')	

		DECLARE @WorkflowLetter NVARCHAR (100)=
		(SELECT WorkflowLetter FROM  wfd_Workflows WF INNER JOIN wfi_WorkflowInstances WI	
				ON WF.WorkflowCode=WI.WorkflowCode INNER JOIN wfi_PoolInstances PI
				ON WI.PoolInstanceCode=PI.PoolInstanceCode	WHERE DTC=@BusinessPlan_DTC AND CompileDC=@DocumentCode)
				
		DECLARE @WorkfloName NVARCHAR (445)= (SELECT WorkflowName FROM wfd_Workflows WHERE WorkflowLetter=@WorkflowLetter)
		DECLARE @WorkfloCode NVARCHAR (445)= (SELECT WorkflowCode FROM wfd_Workflows WHERE WorkflowLetter=@WorkflowLetter)
	
		DECLARE @FormCode int --کد فرم طرح كسب و كار		
		=(SELECT FormCode FROM Docs_Forms WHERE FormLetter='FECS08')
-------------------------------------------------------------------------------------------
		
		DECLARE @RoleCodeEX int --کد نقش کارشناس عامل همان استان
		=(select RoleCode from Users_Roles_managment WITH(NOLOCK) where RoleLetter = 'FEAGEX')
				
		DECLARE @RoleCodeFE int --کد نقش کارشناس عامل اصلي
	    =(select RoleCode from Users_Roles_managment WITH(NOLOCK) where RoleLetter = 'FEAGEXMA')
				

		---- بازیابی کد کاربری بررسي دبيرخانه جشنواره
		SELECT @Festival_UserCode = UserCode FROM Orgs_Units OU  INNER JOIN Users_Roles UR 
			ON OU.UnitCode = UR.UnitCode INNER JOIN Users_Roles_Managment URM ON URM.RoleCode = UR.RoleCode
				WHERE URM.RoleLetter = 'STFEBB' AND OU.UnitLetter = 'FE' 
		-----------------------------------------------
		-- بازیابی کد کاربری كارشناس عامل اصلي
	    IF @SecretariatExpCode='' or @SecretariatExpCode is null
		begin   
		 SELECT @SecretariatExpCode = [dbo].[func_LoadBalance2] (@RoleCodeFE,'FE' ,@BusinessPlan_DTC ,@FormCode ,@DocumentCode)
  
	     UPDATE CMSI_FECS_BusinessPlan_Compile SET FECS08H02_SecretariatExpCode=@SecretariatExpCode WHERE DocumentCode = @DocumentCode
        end

		-----------------------------------------------
		IF @AgentCode='' or @AgentCode is null
		begin
		--جدول براي نگهداري كد عامل هايي كه براي اين استان تعريف شده اند و تعداد طرح هايي كه تاكنون براي هر عامل وجود دارد
		DECLARE @AgentTemp table(AgentCode nvarchar(max),FormCount int)
		
		INSERT INTO @AgentTemp
		--اگر براي استان محل اقامت متقاضي عامل فعالي براي سال جاري تعرف شده باشد
		select FECS02h01_FactorCode,(select COUNT(*) from CMSI_FECS_BusinessPlan_Compile
		where FECS08H02_AgentCode=FECS02h01_FactorCode and FECS08H01_FestivalNo=@FestivalNo) 
		 from CMSI_FECS_FactorDefinition FD inner join CMSI_FECS_ActivFactors_Compile AF
		  ON FD.FECS02h01_FactorCode=FECS28H01_FactorName where FECS28H03_SubFactorCheckResult='Confirm'
			 and FECS28H01_festivalNo=@FestivalNo and
			   (FECS02H01_Provincescovered_SubFields_XML like '%"'+@ResidenceState+'"%' )
			   
	  
		--اگر براي استان محل اقامت متقاضي عامل فعالي براي سال جاري تعرف نشده باشد 			 
		IF (select COUNT(*) from @AgentTemp	)=0
		BEGIN
			INSERT INTO @AgentTemp
			 SELECT FECS01H01_FactorMain,(select COUNT(*) from CMSI_FECS_BusinessPlan_Compile
			   where FECS08H02_AgentCode=FECS01H01_FactorMain and FECS08H01_FestivalNo=@FestivalNo) 
				  from CMSI_FECS_FestivalDefine_Compile where FECS01H01_ActiveFes=1	       
			
			SET @RoleCodeEX = @RoleCodeFE	-- كد كارشناس عامل اصلي
			SET @ResidenceState = 'FE'  -- واحد سازماني كارشناس عامل اصلي
		END
		
		 SELECT TOP 1 @AgentCode=AgentCode from @AgentTemp order by FormCount ASC	

	     UPDATE CMSI_FECS_BusinessPlan_Compile SET FECS08H02_AgentCode=@AgentCode WHERE DocumentCode = @DocumentCode
	   end
       ------------------------------------------

       --کارشناس عامل
	    IF @AgentCodeExp='' or @AgentCodeExp is null
		begin  
			
			 declare @UserCode int
			 declare @table table(usercode int)-- جدول برای نگهداری خروجی لود بالانس جدولی
			 insert into @table
			 exec [dbo].[WFSF_GEN_LoadBalanceTable]  
			  @RoleCode=@RoleCodeEX,@UnitLetter=@ResidenceState,@DTC=@BusinessPlan_DTC,@FormCode=@FormCode,@documentcode=@DocumentCode
				
			 declare @table1 table(usercode int)-- جدول برای نگهداری کارشناسان عامل مورد نظر
			 insert into @table1
			 select usercode from Users_PersonalInfo inner join CMSI_FECS_PersonInformation_compile ON
			 FECS27H01_NationalCode=NationalCode where FECS27H01_FactorCode= @AgentCode
			   and (FECS27H01_SubFactorCode is null or FECS27H01_SubFactorCode='') and FECS27H01_Side='FEAGEX'		  	    
		    
			 while (select COUNT(*) from @table)<>0
			  begin
				   select TOP 1 @UserCode=usercode from @table
				   if exists (select usercode from @table1 where usercode=@UserCode)
					  begin 
						select @AgentCodeExp=@UserCode
						delete @table
					  end
				   delete @table where usercode = @UserCode
			   end
			   
			 UPDATE CMSI_FECS_BusinessPlan_Compile SET  FECS08H02_AgentExpertCode=@AgentCodeExp WHERE DocumentCode = @DocumentCode
		end
       ------------------------------------------
		select @AgentCodeMGMT= usercode from Users_PersonalInfo inner join CMSI_FECS_PersonInformation_compile ON
		 FECS27H01_NationalCode=NationalCode where FECS27H01_FactorCode= @AgentCode
		   and (FECS27H01_SubFactorCode is null or FECS27H01_SubFactorCode='') and FECS27H01_Side='FEAGMA'		  	    
	    
		select @SubAgentCodeMGMT= usercode from Users_PersonalInfo inner join CMSI_FECS_PersonInformation_compile ON
		 FECS27H01_NationalCode=NationalCode where FECS27H01_FactorCode= @AgentCode
		   and FECS27H01_SubFactorCode=@SubAgentCode and FECS27H01_Side='FESAMA'		  	    
	    
	    SELECT @AutoFinishTask=TI.TaskInstanceCode FROM
                    wfi_PoolInstances AS PIN INNER JOIN wfi_WorkflowInstances AS WI ON 
				      PIN.PoolInstanceCode = WI.PoolInstanceCode INNER JOIN wfi_StateInstances AS SI ON 
					    WI.WFInstanceCode = SI.WFInstanceCode  INNER JOIN wfi_TaskInstances AS TI ON 
					      SI.STInstanceCode = TI.STInstanceCode INNER JOIN wfd_Workflows AS WF ON WF.DocumentTypeCode=PIN.DTC
							WHERE PIN.DTC =@BusinessPlan_DTC AND PIN.compileDC=@DocumentCode and WF.WorkflowLetter='FECS08' 
							  and PIN.PoolFinished = 0 AND SI.STFinished = 0 and TI.FinishAutomatic=1
		-------------------------------------------------
	    -- کد مرحله جاری
		SELECT @StateLetter = StateLetter FROM wfd_WorkflowsStates WITH(NOLOCK) WHERE StateCode = @StateCode
		SELECT @CurrentDate =GETDATE()
		------------------------------------------------------------------------------------------------------		
		IF @StateLetter IN ('FECS08S01') -- مرحله اول-ثبت اطلاعات طرح كسب و كار 
			BEGIN
			--طرح هایی که در مرحله ی اول هستند و تاریخ آنها از تاریخ اتمام طرح های تکمیل نشده گذشته باشد باید خاتمه یابند
			IF(@CurrentDate>@SummeryRegistrationEndDate)
			  begin		
				SET @ReturnValue = 13 -- اتمام
				SET @ErrorMessage = N'' 			
				SET @UserCodesXML ='<UserRoot>'+'<UserCode Value="-1" />'+'</UserRoot>'				
				SET @EmailXML =N'<EmailRoot>'+
						N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام&lt;br&gt;'
						+N' احتراما به استحضار مي رساند،متاسفانه طرح شما به دليل اتمام زمان ثبت طرح, ثبت نشد '						
						+N'&lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;&lt;br&gt;با تشكر&lt;br&gt;&lt;b&gt; 
						دبيرخانه جشنواره ملي شيخ بهايي&lt;/b&gt;&lt;/p&gt;&lt;/p&gt;" >'+
						N'<UserCode Value="'+CONVERT(nvarchar(max),@CreatingUserCode)+'" />'+
						N'	</Email>'+
						N'</EmailRoot>'	
			 end

			--طرح هایی که در مرحله ی اول هستند و تاریخ آنها از مهلت ثبت نام گذشته باشد باید بروند دست دبیر خانه
			 ELSE IF(@CurrentDate>@RegistrationDeadline)
			  begin		
				SET @ReturnValue = 4 -- دبیر خانه 
				SET @ErrorMessage = N'' 			
				SET @UserCodesXML = '<UserRoot>'+
									'<UserCode Value="'+@SecretariatExpCode+'" />'+
									'</UserRoot>'-- کد يوزر کارشناس دبيرخانه جشنواره				
			    SET @EmailXML =N'<EmailRoot>'+
						N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام&lt;br&gt;جناب آقاي/ سركار خانم'+N' '
						+@FormCompeleteName+N' احتراما به استحضار مي رساند، ثبت و ارسال طرح '+ '&lt;font color=&quot;blue&quot;&gt;'
						+N'«  '+@PlanTitle +N' »'+'&lt;/font&gt;'+
						+N'در قالب فرم'+ '&lt;font color=&quot;blue&quot;&gt;'
					    +N'« '+@WorkfloName+N' »'+'&lt;/font&gt;'
					    +N' به'+N' '+@FestivalPr +N' '+N' جشنواره ملي شيخ بهايي با موفقيت انجام شد. &lt;br&gt;'
						+N'لازم به ذكر است پس از بررسي اوليه، نتيجه بررسي به اطلاع جنابعالي خواهد رسيد.
						&lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;&lt;br&gt;با تشكر&lt;br&gt;&lt;b&gt; 
						دبيرخانه جشنواره ملي شيخ بهايي&lt;/b&gt;&lt;/p&gt;&lt;/p&gt;" >'+
						N'<UserCode Value="'+CONVERT(nvarchar(max),@CreatingUserCode)+'" />'+
						N'	</Email>'+
						N'</EmailRoot>'	
			  end			
			
		ELSE --حالت عادی طرح
		 begin										
				SET @ReturnValue = 2 -- مرحله دوم
				SET @ErrorMessage = N''   
				SET @UserCodesXML ='<UserRoot>'+
									'<UserCode Value="'+CONVERT(NVARCHAR(50),@Festival_UserCode)+'" />'+
									'</UserRoot>'-- کد يوزر بررسي دبيرخانه جشنواره
									
			    SET @EmailXML =N'<EmailRoot>'+
						N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام&lt;br&gt;جناب آقاي/ سركار خانم'+N' '
						+@FormCompeleteName+N' احتراما به استحضار مي رساند، ثبت و ارسال طرح '+ '&lt;font color=&quot;blue&quot;&gt;'
						+N'«  '+@PlanTitle +N' »'+'&lt;/font&gt;'+
						+N'در قالب فرم'+ '&lt;font color=&quot;blue&quot;&gt;'
					    +N'« '+@WorkfloName+N' »'+'&lt;/font&gt;'
					    +N' به'+N' '+@FestivalPr +N' '+N' جشنواره ملي شيخ بهايي با موفقيت انجام شد. &lt;br&gt;'
						+N'لازم به ذكر است پس از بررسي اوليه، نتيجه بررسي به اطلاع جنابعالي خواهد رسيد.
						&lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;&lt;br&gt;با تشكر&lt;br&gt;&lt;b&gt; 
						دبيرخانه جشنواره ملي شيخ بهايي&lt;/b&gt;&lt;/p&gt;&lt;/p&gt;" >'+
						N'<UserCode Value="'+CONVERT(nvarchar(max),@CreatingUserCode)+'" />'+
						N'	</Email>'+
						N'</EmailRoot>'	
			end
			
		SET @SMSXML = N''
		SET @MessageXML = N''
		SET @ExtraOutputXML = N''
		END
	------------------------------------------------------------------------------------------------------
		IF @StateLetter='FECS08S02' -- مرحله دوم-بررسي کننده دبيرخانه
			BEGIN
				SET @ReturnValue = 12 -- مرحله پرداخت الکترونیکی
				SET @ErrorMessage = N'' 
				SET @UserCodesXML =	'<UserRoot>'+ --گيرنده:متقاضی
							'<UserCode Value="'+@CreatingUserCode+'" />'+
							'</UserRoot>'
				SET @EmailXML = N''	
				SET @SMSXML = N''
				SET @MessageXML = N''
				SET @ExtraOutputXML = N''
			 END
	------------------------------------------------------------------------------------------------------
		IF @StateLetter ='FECS08S12'--  مرحله ي پرداخت
			BEGIN
			  IF @Dissuasion  =1     --اگر انصراف زد گردش تمام شود
			   begin
				SET @ReturnValue = 13 -- اتمام
				SET @ErrorMessage = N'' 
				SET @UserCodesXML =	'<UserRoot>'+'<UserCode Value="-1" />'+'</UserRoot>'
				SET @EmailXML = N''	
				SET @SMSXML = N''
				SET @MessageXML = N''
				SET @ExtraOutputXML = N''
			   end
   
			 ELSE 
			   begin	
			   	--طرح هایی که در مرحله ی اول هستند و تاریخ آنها از مهلت ثبت نام گذشته باشد باید بروند دست دبیر خانه
	            IF(@CurrentDate>@RegistrationDeadline)
				  begin		
					SET @ReturnValue = 4 -- دبیر خانه 
					SET @ErrorMessage = N'' 			
					SET @UserCodesXML = '<UserRoot>'+
										'<UserCode Value="'+@SecretariatExpCode+'" />'+
										'</UserRoot>'-- کد يوزر کارشناس دبيرخانه جشنواره				
					SET @EmailXML =N'<EmailRoot>'+
							N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام&lt;br&gt;جناب آقاي/ سركار خانم'+N' '
							+@FormCompeleteName+N' احتراما به استحضار مي رساند، ثبت و ارسال طرح '+ '&lt;font color=&quot;blue&quot;&gt;'
							+N'«  '+@PlanTitle +N' »'+'&lt;/font&gt;'+
							+N'در قالب فرم'+ '&lt;font color=&quot;blue&quot;&gt;'
							+N'« '+@WorkfloName+N' »'+'&lt;/font&gt;'
							+N' به'+N' '+@FestivalPr +N' '+N' جشنواره ملي شيخ بهايي با موفقيت انجام شد. &lt;br&gt;'
							+N'لازم به ذكر است پس از بررسي ، نتيجه بررسي به اطلاع جنابعالي خواهد رسيد.
							&lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;&lt;br&gt;با تشكر&lt;br&gt;&lt;b&gt; 
							دبيرخانه جشنواره ملي شيخ بهايي&lt;/b&gt;&lt;/p&gt;&lt;/p&gt;" >'+
							N'<UserCode Value="'+CONVERT(nvarchar(max),@CreatingUserCode)+'" />'+
							N'	</Email>'+
							N'</EmailRoot>'	
				  end			
			
			    ELSE
				   begin
					SET @ReturnValue = 3 -- مرحله سوم :بررسي عامل
					SET @ErrorMessage = N'' 
					SET @UserCodesXML =	'<UserRoot>'+ --گيرنده:كارشناس عامل مرتبط
								'<UserCode Value="'+@AgentCodeExp+'" />'+
								'</UserRoot>'
					SET @EmailXML =N'<EmailRoot>'+
									N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام&lt;br&gt;جناب آقاي/ سركار خانم'+N' '
									+@FormCompeleteName+N' احتراما به استحضار مي رساند، ثبت و ارسال طرح '+ '&lt;font color=&quot;blue&quot;&gt;'
									+N'«  '+@PlanTitle +N' »'+'&lt;/font&gt;'+
									+N'در قالب فرم'+ '&lt;font color=&quot;blue&quot;&gt;'
									+N'« '+@WorkfloName+N' »'+'&lt;/font&gt;'
									+N' به'+N' '+@FestivalPr +N' '+N' جشنواره ملي شيخ بهايي با موفقيت انجام شد. &lt;br&gt;'
									+N'لازم به ذكر است پس از بررسي ، نتيجه بررسي به اطلاع جنابعالي خواهد رسيد.
									&lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;&lt;br&gt;با تشكر&lt;br&gt;&lt;b&gt; 
									دبيرخانه جشنواره ملي شيخ بهايي&lt;/b&gt;&lt;/p&gt;&lt;/p&gt;" >'+
									N'<UserCode Value="'+CONVERT(nvarchar(max),@CreatingUserCode)+'" />'+
									N'	</Email>'+
									N'</EmailRoot>'				
					SET @SMSXML = N''
					SET @MessageXML = N''
					SET @ExtraOutputXML = N''
				   end
			  end
		  END 
   ------------------------------------------------------------------------------------------------------
		IF @StateLetter ='FECS08S07' --  مرحله ي اصلاح طرح
			BEGIN
			  if @SecretariatCheckResult='ApplicantReform' --اگر دبیرخانه فرم را برای اصلاح فرستاده بود
			    begin
					SET @ReturnValue = 4 -- مرحله سوم :بررسي دبیرخانه
					SET @ErrorMessage = N'' 
					SET @UserCodesXML =	'<UserRoot>'+ --گيرنده:كارشناس دبیرخانه
								'<UserCode Value="'+@SecretariatExpCode+'" />'+
								'</UserRoot>'
					SET @EmailXML = N''	
					SET @SMSXML = N''
					SET @MessageXML = N''
					SET @ExtraOutputXML = N''
			    end
			    
			    ELSE
				 begin
					SET @ReturnValue = 3 -- مرحله سوم :بررسي عامل
					SET @ErrorMessage = N'' 
					SET @UserCodesXML =	'<UserRoot>'+ --گيرنده:كارشناس عامل مرتبط
								'<UserCode Value="'+@AgentCodeExp+'" />'+
								'</UserRoot>'
					SET @EmailXML = N''	
					SET @SMSXML = N''
					SET @MessageXML = N''
					SET @ExtraOutputXML = N''
				 end 
			 END 
	------------------------------------------------------------------------------------------------------
		IF @StateLetter IN ('FECS08S03','FECS08S09','FECS08S10', 'FECS08S11')-- مرحله سوم-بررسي عامل و مراحل مربوط به بررسي مجدد عامل
		 BEGIN
		 
		 	-- اگر اين مرحله به صورت خودكار تمام شده یا 35 روز از تاریخ بررسی کارشناس عامل گذشته است
			IF (@AutoFinishTask<>'' and @AutoFinishTask is not null) or (@CurrentDate> cast(@CheckDate as DATETIME)+35)
			begin
				SET @ReturnValue = 4 -- بررسي كارشناس دبيرخانه
				SET @ErrorMessage = N'' 			
				SET @UserCodesXML =	'<UserRoot>'+ 
							'<UserCode Value="'+@SecretariatExpCode+'" />'+
							'</UserRoot>'
			    SET @EmailXML =N'<EmailRoot>'+
						N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام&lt;br&gt;'+N' '
						+N' احتراما به استحضار مي رساند، به دليل عدم تكميل فرم '						
						+ '&lt;font color=&quot;blue&quot;&gt;'
					    +N'« '+@WorkfloName+N' »'+'&lt;/font&gt;'+N'مربوط به آقاي/ خانم '+@FormCompeleteName+
					    +N'در موعد مقرر ، فرم از كارتابل شما خارج شد.
						&lt;/p&gt;&lt;/p&gt;" >'+
						N'<UserCode Value="'+CONVERT(nvarchar(max),@AgentCodeExp)+'" />'+
						N'	</Email>'+
						N'</EmailRoot>'
				SET @EmailXML = N''
				SET @SMSXML = N''
				SET @MessageXML = N''
				SET @ExtraOutputXML = N''
			end
			
			ELSE BEGIN--اتمام دستي مرحله
			IF (@ExpertCheckResult='AgentArbitration')--داوري عامل
			begin		
				SET @ReturnValue = 6 -- مرحله سوم :بررسي مدير عامل
				SET @ErrorMessage = N'' 			
				SET @UserCodesXML =	'<UserRoot>'+ --گيرنده:كارشناس عامل مرتبط
							        '<UserCode Value="'+@AgentCodeMGMT+'" />'+
							        '</UserRoot>'										
				SET @EmailXML = N''	
				SET @SMSXML = N''
				SET @MessageXML = N''
				SET @ExtraOutputXML = N''
			end

			ELSE IF (@ExpertCheckResult='SubAgentArbitration')--داوري زيرعامل
			begin		
				SET @ReturnValue = 5 -- مرحله داوري زيرعامل
				SET @ErrorMessage = N'' 			
				SET @UserCodesXML =	'<UserRoot>'+ --گيرنده:مدير زيرعامل مرتبط
							        '<UserCode Value="'+@SubAgentCodeMGMT+'" />'+
							        '</UserRoot>'										
				SET @EmailXML = N''	
				SET @SMSXML = N''
				SET @MessageXML = N''
				SET @ExtraOutputXML = N''
			end
			
			ELSE IF (@ExpertCheckResult='ApplicantReform')--اصلاح طرح
			begin		
				SET @ReturnValue = 7 -- مرحله اصلاح طرح
				SET @ErrorMessage = N'' 			
				SET @UserCodesXML =	'<UserRoot>'+ --گيرنده:كارشناس عامل مرتبط
							        '<UserCode Value="'+@CreatingUserCode+'" />'+
							        '</UserRoot>'										
				SET @EmailXML =N'<EmailRoot>'+
						N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام&lt;br&gt;جناب آقاي/ سركار خانم'+N' '
						+@FormCompeleteName+N' احتراما به استحضار مي رساند، فرم '						
						+ '&lt;font color=&quot;blue&quot;&gt;'
					    +N'« '+@WorkfloName+N' »'+'&lt;/font&gt;'
					    +N'جهت اصلاح اطلاعات طرح به كارتابل شما وارد شد.'
						+N'&lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;&lt;br&gt;با تشكر&lt;br&gt;&lt;b&gt; 
						كارشناس عامل جشنواره ملي شيخ بهايي&lt;/b&gt;&lt;/p&gt;&lt;/p&gt;" >'+
						N'<UserCode Value="'+CONVERT(nvarchar(max),@CreatingUserCode)+'" />'+
						N'	</Email>'+
						N'</EmailRoot>'
				SET @SMSXML = N''
				SET @MessageXML = N''
				SET @ExtraOutputXML = N''
			end
			
			
			ELSE IF (@ExpertCheckResult='Reject')--رد طرح
			begin		
				SET @ReturnValue = 13 -- اتمام
				SET @ErrorMessage = N'' 			
				SET @UserCodesXML =	'<UserRoot>'+'<UserCode Value="-1" />'+'</UserRoot>'										
				IF @SecretariatCheckResult='Reject'										
				  SET @EmailXML =N'<EmailRoot>'+
						N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام&lt;br&gt;'
						+N' احتراما به استحضار مي رساند،متاسفانه با طرح شما به دليل '						
						+ '&lt;font color=&quot;blue&quot;&gt;'
					    +N'« '+@FormRejectionResult+N' »'+'&lt;/font&gt;'
					    +N'موافقت نشد.'
						+N'&lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;&lt;br&gt;با تشكر&lt;br&gt;&lt;b&gt; 
						كارشناس عامل جشنواره ملي شيخ بهايي&lt;/b&gt;&lt;/p&gt;&lt;/p&gt;" >'+
						N'<UserCode Value="'+CONVERT(nvarchar(max),@CreatingUserCode)+'" />'+
						N'	</Email>'+
						N'</EmailRoot>'
				ELSE	
				  SET @EmailXML = N''
				SET @SMSXML = N''
				SET @MessageXML = N''
				SET @ExtraOutputXML = N''
			end			
		  END
		 END 				
	------------------------------------------------------------------------------------------------------
		IF @StateLetter IN ('FECS08S04') -- مرحله چهارم-بررسي دبيرخانه 
			BEGIN
			IF @SecretariatCheckResult IN('AgentArbitration','Reject')--داوري يا رد طرح 
			begin		
				SET @ReturnValue = 13 -- اتمام
				SET @ErrorMessage = N'' 			
				SET @UserCodesXML =	'<UserRoot>'+'<UserCode Value="-1" />'+'</UserRoot>'
				
				IF @SecretariatCheckResult='Reject'										
				  SET @EmailXML =N'<EmailRoot>'+
						N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام&lt;br&gt;'
						+N' احتراما به استحضار مي رساند،متاسفانه با طرح شما به دليل '						
						+ '&lt;font color=&quot;blue&quot;&gt;'
					    +N'« '+@FormRejectionResult+N' »'+'&lt;/font&gt;'
					    +N'موافقت نشد.'
						+N'&lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;&lt;br&gt;با تشكر&lt;br&gt;&lt;b&gt; 
						دبيرخانه جشنواره ملي شيخ بهايي&lt;/b&gt;&lt;/p&gt;&lt;/p&gt;" >'+
						N'<UserCode Value="'+CONVERT(nvarchar(max),@CreatingUserCode)+'" />'+
						N'	</Email>'+
						N'</EmailRoot>'
				ELSE	
				  SET @EmailXML = N''
				SET @SMSXML = N''
				SET @MessageXML = N''
				SET @ExtraOutputXML = N''
			end

			ELSE IF (@SecretariatCheckResult='ApplicantReform')--اصلاح طرح
			begin		
				SET @ReturnValue = 7 -- مرحله اصلاح طرح
				SET @ErrorMessage = N'' 			
				SET @UserCodesXML =	'<UserRoot>'+ --گيرنده:كارشناس عامل مرتبط
							        '<UserCode Value="'+@CreatingUserCode+'" />'+
							        '</UserRoot>'										
				SET @EmailXML =N'<EmailRoot>'+
						N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام&lt;br&gt;جناب آقاي/ سركار خانم'+N' '
						+@FormCompeleteName+N' احتراما به استحضار مي رساند، فرم '						
						+ '&lt;font color=&quot;blue&quot;&gt;'
					    +N'« '+@WorkfloName+N' »'+'&lt;/font&gt;'
					    +N'جهت اصلاح اطلاعات طرح به كارتابل شما وارد شد.'
						+N'&lt;br&gt;&lt;br&gt;&lt;p align=&quot;center&quot;&gt;&lt;br&gt;با تشكر&lt;br&gt;&lt;b&gt; 
						دبيرخانه جشنواره ملي شيخ بهايي&lt;/b&gt;&lt;/p&gt;&lt;/p&gt;" >'+
						N'<UserCode Value="'+CONVERT(nvarchar(max),@CreatingUserCode)+'" />'+
						N'	</Email>'+
						N'</EmailRoot>'
				SET @SMSXML = N''
				SET @MessageXML = N''
				SET @ExtraOutputXML = N''
			end		
			
		 END 
------------------------------------------------------------------------------------------------------
		IF @StateLetter IN ('FECS08S05') -- مرحله پنجم-داوري زيرعامل 
			BEGIN
			--اگر 35 روز از تاریخ بررسی کارشناس عامل گذشته است
			IF (@CurrentDate> cast(@CheckDate as DATETIME)+35)
			 begin
				SET @ReturnValue = 4 -- بررسي كارشناس دبيرخانه
				SET @ErrorMessage = N'' 			
				SET @UserCodesXML =	'<UserRoot>'+ 
							'<UserCode Value="'+@SecretariatExpCode+'" />'+
							'</UserRoot>'				
			 end
			 
			 ELSE begin
			
					SET @ReturnValue = 8 -- مرحله هشتم :بررسي داوري هاي زيرعامل
					SET @ErrorMessage = N'' 
					SET @UserCodesXML =	'<UserRoot>'+ --گيرنده:مديرعامل
								'<UserCode Value="'+@AgentCodeExp+'" />'+
								'</UserRoot>'
				  end
				  		
			--اگر اين مرحله به صورت خودكار تمام شده 
			IF (@AutoFinishTask<>'' and @AutoFinishTask is not null)
		
			    SET @EmailXML =N'<EmailRoot>'+
						N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام&lt;br&gt;'+N' '
						+N' احتراما به استحضار مي رساند، به دليل عدم تكميل فرم '						
						+ '&lt;font color=&quot;blue&quot;&gt;'
					    +N'« '+@WorkfloName+N' »'+'&lt;/font&gt;'+N'مربوط به آقاي/ خانم '+@FormCompeleteName+
					    +N'در موعد مقرر ، فرم از كارتابل شما خارج شد.
						&lt;/p&gt;&lt;/p&gt;" >'+
						N'<UserCode Value="'+CONVERT(nvarchar(max),@SubAgentCodeMGMT)+'" />'+
						N'	</Email>'+
						N'</EmailRoot>'
						
			ELSE --اگر اين مرحله به صورت خودكار تمام نشده
				SET @EmailXML =N''
				
				SET @SMSXML = N''
				SET @MessageXML = N''
				SET @ExtraOutputXML = N''
		   END	
------------------------------------------------------------------------------------------------------
		IF @StateLetter IN ('FECS08S06') -- مرحله ششم-بررسي مدير عامل 
			BEGIN
	 
		 	-- اگر اين مرحله به صورت خودكار تمام شده یا 35 روز از تاریخ بررسی کارشناس عامل گذشته است
			IF (@AutoFinishTask<>'' and @AutoFinishTask is not null) or (@CurrentDate> cast(@CheckDate as DATETIME)+35)
			begin
				SET @ReturnValue = 4 -- بررسي كارشناس دبيرخانه
				SET @ErrorMessage = N'' 			
				SET @UserCodesXML =	'<UserRoot>'+ 
							'<UserCode Value="'+@SecretariatExpCode+'" />'+
							'</UserRoot>'
			    SET @EmailXML =N'<EmailRoot>'+
						N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام&lt;br&gt;'+N' '
						+N' احتراما به استحضار مي رساند، به دليل عدم تكميل فرم '						
						+ '&lt;font color=&quot;blue&quot;&gt;'
					    +N'« '+@WorkfloName+N' »'+'&lt;/font&gt;'+N'مربوط به آقاي/ خانم '+@FormCompeleteName+
					    +N'در موعد مقرر ، فرم از كارتابل شما خارج شد.
						&lt;/p&gt;&lt;/p&gt;" >'+
						N'<UserCode Value="'+CONVERT(nvarchar(max),@AgentCodeMGMT)+'" />'+
						N'	</Email>'+
						N'</EmailRoot>'
				SET @SMSXML = N''
				SET @MessageXML = N''
				SET @ExtraOutputXML = N''
			end
			
			ELSE BEGIN--اتمام دستي مرحله
			IF @ManagerResultCheck ='Verified'--تاييد 
			begin		
				SET @ReturnValue = 13 -- اتمام
				SET @ErrorMessage = N'' 			
				SET @UserCodesXML =	'<UserRoot>'+'<UserCode Value="-1" />'+'</UserRoot>'
				SET @EmailXML = N''
				SET @SMSXML = N''
				SET @MessageXML = N''
				SET @ExtraOutputXML = N''
			end

			ELSE BEGIN				
				IF @ManagerResultCheck='FurtherArbitration'--ارجاع به کارشناس عامل جهت داوری مجدد			
					SET @ReturnValue = 9 			
				
				ELSE IF @ManagerResultCheck='AgentChange'--ارجاع به کارشناس عامل جهت تغییر زیرعامل			
					SET @ReturnValue = 10 				
				
				ELSE IF @ManagerResultCheck='PlanReform'--ارجاع به کارشناس عامل جهت اصلاح اطلاعات طرح					
					SET @ReturnValue = 11 

					SET @ErrorMessage = N'' 			
					SET @UserCodesXML =	'<UserRoot>'+ --گيرنده:كارشناس عامل مرتبط
										'<UserCode Value="'+@AgentCodeExp+'" />'+
										'</UserRoot>'										
					SET @EmailXML =N''
					SET @SMSXML = N''
					SET @MessageXML = N''
					SET @ExtraOutputXML = N''
			     END
			     
			   END
		 END 
------------------------------------------------------------------------------------------------------
		IF @StateLetter IN ('FECS08S08') -- مرحله هشتم :بررسي داوري هاي زيرعامل 
			BEGIN
			   -- اگر 35 روز از تاریخ بررسی کارشناس عامل گذشته است
			   IF (@CurrentDate> cast(@CheckDate as DATETIME)+35)
					begin
						SET @ReturnValue = 4 -- بررسي كارشناس دبيرخانه
						SET @ErrorMessage = N'' 			
						SET @UserCodesXML =	'<UserRoot>'+ 
									'<UserCode Value="'+@SecretariatExpCode+'" />'+
									'</UserRoot>'
					end
					
			ELSE begin
						SET @ReturnValue = 6 -- مرحله ششم :بررسي مديرعامل
						SET @ErrorMessage = N'' 
						SET @UserCodesXML =	'<UserRoot>'+ --گيرنده:مديرعامل
									'<UserCode Value="'+@AgentCodeMGMT+'" />'+
									'</UserRoot>'
									
					   --اگر اين مرحله به صورت خودكار تمام شده
					  IF (@AutoFinishTask<>'' and @AutoFinishTask is not null)
				
						SET @EmailXML =N'<EmailRoot>'+
								N'	<Email Text=" &lt;p style=&quot;font-family:tahoma&quot;&gt;&lt;br&gt;با سلام&lt;br&gt;'+N' '
								+N' احتراما به استحضار مي رساند، به دليل عدم تكميل فرم '						
								+ '&lt;font color=&quot;blue&quot;&gt;'
								+N'« '+@WorkfloName+N' »'+'&lt;/font&gt;'+N'مربوط به آقاي/ خانم '+@FormCompeleteName+
								+N'در موعد مقرر ، فرم از كارتابل شما خارج شد.
								&lt;/p&gt;&lt;/p&gt;" >'+
								N'<UserCode Value="'+CONVERT(nvarchar(max),@AgentCodeExp)+'" />'+
								N'	</Email>'+
								N'</EmailRoot>'
								
					  ELSE --اگر اين مرحله به صورت خودكار تمام نشده
						SET @EmailXML =N''
			  end
				
				SET @SMSXML = N''
				SET @MessageXML = N''
				SET @ExtraOutputXML = N''
			 END 

-------------------------------------------------------------------------------------------------------------------	
	IF @ReturnValue=13
	BEGIN
		--هرجا که گردش تمام شد تمام داوری های نا تمام را هم تمام می کنیم
		EXEC Gen_AutoFinish_RelatedWFs @MasterDTC= @DTC_BusinessPlanArbiteration , @RelatedDTC= @DTC_BusinessPlanArbiteration ,
			   @MasterDC=@DocumentCode	
	   		--===========================نقش هاي مورد نياز براي مجوزهاي دسترسي  به پرونده==================================
		-- كد نقش مسئول دبيرخانه جشنوراه
		DECLARE @STFERSRoleCode NVARCHAR(10) = (SELECT RoleCode FROM Users_Roles_Managment WHERE RoleLetter = 'STFERS')		

		DECLARE @UnitCode NVARCHAR(10) -- كد واحد سازماني مسئول و کارشناس دبیرخانه		
		SELECT @UnitCode =UnitCode FROM Orgs_Units WHERE UnitLetter = 'FESE'
		
		SELECT @ResidenceState=FECS08H01_ResidenceState
	         FROM CMSI_FECS_BusinessPlan_Compile WHERE DocumentCode = @DocumentCode
			
		
		DECLARE @UnitCodeAgent NVARCHAR(10) -- كد واحد سازماني مدیر و کارشناس عامل و مدیر زیرعامل		
		SELECT @UnitCodeAgent =  UnitCode FROM Orgs_Units WHERE UnitLetter = @ResidenceState
		
		DECLARE @RoleCodeMGMT NVARCHAR(10) -- كدنقش مدیر عامل		
		SELECT @RoleCodeMGMT =  RoleCode FROM Users_Roles_Managment WHERE RoleLetter = 'FEAGMA'
		
		DECLARE @RoleCodeSubMGMT NVARCHAR(10) -- كدنقش مدیر زیرعامل		
		SELECT @RoleCodeSubMGMT = RoleCode FROM Users_Roles_Managment WHERE RoleLetter = 'FESAMA'
		
		DECLARE @PermissionXML XML -- براي مجوز دسترسي هاي پرونده
		
		SET @PermissionXML = '<Permissions>'+
					 '<Permission RowID = "1" RoleCode = "' +cast(@RoleCodeFE as nvarchar(10)) + '" UnitCode = "'+ @UnitCode +
						'" PermissionType = "1" />'+
					 '<Permission RowID = "2" RoleCode = "' +@STFERSRoleCode + '" UnitCode = "'+ @UnitCode +
						'" PermissionType = "1" />'+
					 '<Permission RowID = "3" RoleCode = "' +cast(@RoleCodeEX as nvarchar(10)) + '" UnitCode = "'+ @UnitCodeAgent +
						'" PermissionType = "1" />'+
					 '<Permission RowID = "4" RoleCode = "'+@RoleCodeMGMT +'" UnitCode = "'+ @UnitCodeAgent +
						'" PermissionType = "1" />'+
					 '<Permission RowID = "5" RoleCode = "'+@RoleCodeSubMGMT +'" UnitCode = "'+ @UnitCodeAgent +
						'" PermissionType = "1" />'+
				     '</Permissions>'
						
		DECLARE @AssignCode INT -- خروجي پروسيجر قراردادن فرم در پرونده
		DECLARE @Comment NVARCHAR(MAX) -- اسم فرم در پرونده
		
		--*****************قرار دادن فرم تكميل در پرونده پذيرش سال جاري واحد فناور******************
		DECLARE @FolderCode INT -- كد پرونده
		DECLARE @FolderLetter NVARCHAR(50) --كد پرونده
		DECLARE @FolderName NVARCHAR(100) -- نام پرونده طرح کسب و کار
		DECLARE @ParentFolderLetter NVARCHAR(100)='FE' + @FestivalNo

		--SET @CurrentYear = SUBSTRING(@CurrentDate ,3 ,2) -- سال جاري
		
		
		SET @FolderLetter = 'FE' + @FestivalNo+ 'BP'
		
		SET @FolderName =N'طرح کسب و کار '
		
		--SELECT @UnitCode =  UnitCode FROM Orgs_Units WHERE UnitLetter = 'FE'
		
		
		
		EXEC  [dbo].[SP_GEN_ReturnFolderCode]   @FolderLetter = @FolderLetter, 
		@FolderName = @FolderName, @ParentFolderLetter = @ParentFolderLetter , @FolderCode = @FolderCode OUTPUT
								   
		EXEC SP_GEN_AssignFolderPermissions @FolderCode = @FolderCode, @PermissionXML = @PermissionXML	
		----------------------------------------------
		DECLARE @Free_FolderLetter nvarchar(20)='BPFree'+@FestivalNo
		DECLARE @Free_FolderCode int
		DECLARE @Free_FolderName  nvarchar(200)=N'آزاد'
		
		EXEC  [dbo].[SP_GEN_ReturnFolderCode]   @FolderLetter = @Free_FolderLetter, 
		@FolderName = @Free_FolderName, @ParentFolderLetter = @FolderLetter , @FolderCode = @Free_FolderCode OUTPUT
			   
		EXEC SP_GEN_AssignFolderPermissions @FolderCode = @Free_FolderCode, @PermissionXML = @PermissionXML	
		
		-----------------------------------------------
		IF @Dissuasion=1 or @StateLetter ='FECS08S01'  --اگر متقاضی در مرحله پرداخت انصراف داد و یا در مرحله ی اول با اتمام شروط زمانی (تاریخ اتمام طرح های تکمیل نشده) گردش تمام شد
		begin
		DECLARE @Dissuasion_FolderLetter nvarchar(20)='FreeDissuasion'+@FestivalNo
		DECLARE @Dissuasion_FolderCode int
		DECLARE @Dissuasion_FolderName  nvarchar(200)=N'انصراف'
		
		EXEC  [dbo].[SP_GEN_ReturnFolderCode]   @FolderLetter = @Dissuasion_FolderLetter, 
		@FolderName = @Dissuasion_FolderName, @ParentFolderLetter = @Free_FolderLetter , @FolderCode = @Dissuasion_FolderCode OUTPUT
		
		EXEC SP_GEN_AssignFolderPermissions @FolderCode = @Dissuasion_FolderCode, @PermissionXML = @PermissionXML	
			
		SET @Comment = N'ثبت اطلاعات طرح کسب و کار آزاد، ' + @FormCompeleteName

		if Not exists (Select * from wfd_FolderContain where FolderCode=@Dissuasion_FolderCode and DTC=@BusinessPlan_DTC and
		               DC=@DocumentCode and Comment=@Comment and IsCompile=1)
			
		EXEC [dbo].[sp_DocsFolderAssign] @Dissuasion_FolderCode, @BusinessPlan_DTC, @DocumentCode , @Comment , 1 , @AssignCode OUTPUT
	
		end 
		
		---------------==========
		ELSE  -- متقاضی پرداخت را انجام داد
		begin
		DECLARE @Agent_FolderLetter nvarchar(20)='FRBPAG'+@AgentCode+@FestivalNo
		DECLARE @Agent_FolderCode int
		DECLARE @Agent_FolderName  nvarchar(200)=@AgentName
		
-- اگر بخاطر تاريخها در مرحله بررسي كارگروه است و هنوز دست عامل نرفته است و فرم حذف شود
	IF (@StateLetter='FECS08S04') AND (@AgentName IS NULL )
	BEGIN
		SET @AgentName=N' كارگروه طرح هاي كسب و كار'
		SET @Agent_FolderLetter ='FRBPAG'+'BU'+@FestivalNo
		SET @AgentCode= (SELECT FECS01H01_FactorMain FROM CMSI_FECS_FestivalDefine_Compile 
							WHERE FECS01H01_FestivalNo=@FestivalNo AND FECS01H01_ActiveFes=1)
		SET @Agent_FolderLetter ='FRBPAG'+@AgentCode+@FestivalNo
		SET @Agent_FolderName=@AgentName
	END
	
		EXEC  [dbo].[SP_GEN_ReturnFolderCode]   @FolderLetter = @Agent_FolderLetter, 
		@FolderName = @Agent_FolderName, @ParentFolderLetter = @Free_FolderLetter , @FolderCode = @Agent_FolderCode OUTPUT
		
		EXEC SP_GEN_AssignFolderPermissions @FolderCode = @Agent_FolderCode, @PermissionXML = @PermissionXML			
		-----------------------------------------------
	
		--اگر طرح رد شده است
		IF @SecretariatCheckResult='Reject' or @ExpertCheckResult='Reject'
		BEGIN
		
		  DECLARE @Reject_FolderLetter nvarchar(20)='FRBPAGReject'+@AgentCode+@FestivalNo
		  DECLARE @Reject_FolderCode int
		  DECLARE @Reject_FolderName  nvarchar(200)=N'طرح هاي رد شده'			
		
		
	      EXEC  [dbo].[SP_GEN_ReturnFolderCode]  @FolderLetter = @Reject_FolderLetter, 
		  @FolderName = @Reject_FolderName, @ParentFolderLetter = @Agent_FolderLetter 
			   , @FolderCode = @Reject_FolderCode OUTPUT

			SELECT  @Reject_FolderLetter  
		 --*****************اینجا پرمیژن برای مدیر عام و کارشناس عامل همان استان تعریف می کنیم
				   
		  EXEC SP_GEN_AssignFolderPermissions @FolderCode = @Reject_FolderCode, @PermissionXML = @PermissionXML
				
		  SET @Comment = N'ثبت اطلاعات طرح کسب و کار آزاد، ' + @FormCompeleteName

		  if Not exists (Select * from wfd_FolderContain where FolderCode=@Reject_FolderCode and DTC=@BusinessPlan_DTC and
		               DC=@DocumentCode and Comment=@Comment and IsCompile=1)
			
		  EXEC [dbo].[sp_DocsFolderAssign] @Reject_FolderCode, @BusinessPlan_DTC, @DocumentCode , @Comment , 1 , @AssignCode OUTPUT
	  
		END
		
		ELSE
		BEGIN
		
		  DECLARE @SubAgent_FolderLetter nvarchar(20)='FRSubAG'+@SubAgentCode+@FestivalNo
		  DECLARE @SubAgent_FolderCode int
		  DECLARE @SubAgent_FolderName  nvarchar(200)=
		    (select FECS03H01_SubFactorName from CMSI_FECS_SubFactorDefinition where FECS03H01_FormNo=@SubAgentCode)
		    
		  DECLARE @Arbiter_FolderLetter nvarchar(20)='FRBPArbitration'+@AgentCode+@FestivalNo
		  DECLARE @Arbiter_FolderCode int
		  DECLARE @Arbiter_FolderName  nvarchar(200)=N'داوری'
				    
		  --اگر زیرعامل داریم
		  IF @SubAgentCode<>-1
		  begin 
		   EXEC  [dbo].[SP_GEN_ReturnFolderCode]  @FolderLetter = @SubAgent_FolderLetter, 
		      @FolderName = @SubAgent_FolderName, @ParentFolderLetter = @Agent_FolderLetter 
		           , @FolderCode = @SubAgent_FolderCode OUTPUT
		
		 --*****************اینجا پرمیژن برای مدیر عام و کارشناس عامل همان استان تعریف می کنیم
				   
		  EXEC SP_GEN_AssignFolderPermissions @FolderCode = @SubAgent_FolderCode, @PermissionXML = @PermissionXML		  		  		  			
		 end
		-----------------------------------------------
		--اگر زیرعامل نداریم
		ELSE IF @SubAgentCode = -1
		begin 

		  EXEC  [dbo].[SP_GEN_ReturnFolderCode]   @FolderLetter = @Arbiter_FolderLetter, 
		      @FolderName = @Arbiter_FolderName, @ParentFolderLetter = @Agent_FolderLetter 
		           , @FolderCode = @Arbiter_FolderCode OUTPUT

		 --*****************اینجا پرمیژن برای مدیر عام و کارشناس عامل همان استان تعریف می کنیم
				   
		  EXEC SP_GEN_AssignFolderPermissions @FolderCode = @Arbiter_FolderCode, @PermissionXML = @PermissionXML			
		end
		-----------------------------------------------
		--ساخت پرونده برای هر داور با نام داور
	    DECLARE @ArbiterTemp table (ArbiterUserCode nvarchar(max)) 	
	    DECLARE @Arbiter nvarchar(max) 	
		DECLARE @ArbiterName_FolderLetter nvarchar(20)
		DECLARE @ArbiterName_FolderCode int
		DECLARE @ArbiterName_FolderName  nvarchar(200)
		  
		insert into @ArbiterTemp 
		select distinct FECS09H01_ArbiterSelecte from Docs_Related_Records_Compile inner join 
				CMSI_FECS_BusinessPlanArbiteration BPA ON BPA.DocumentCode=RelatedDC where
				  MasterDC=@DocumentCode and MasterDTC=@BusinessPlan_DTC and 
					 RelatedDTC=@DTC_BusinessPlanArbiteration and MasterInCompile=1
						   and RelatedInCompile=0 and FECS09H02_ArbiterCheckOut='Confirm'
						     --and FECS09H01_CreatingUserCode=@SecretariatExpCode 
		
		WHILE (select COUNT(*) from @ArbiterTemp)<>0
		begin 
			select TOP 1 @Arbiter =ArbiterUserCode from @ArbiterTemp
			select @ArbiterName_FolderName=name+' '+family from Users_PersonalInfo where UserCode=@Arbiter
			 
			   IF @SubAgentCode = -1 --اگر زیرعامل نداریم
			   begin
			   	 select @ArbiterName_FolderLetter='FRAr'+@Arbiter+@AgentCode+@FestivalNo

				 EXEC  [dbo].[SP_GEN_ReturnFolderCode]   @FolderLetter = @ArbiterName_FolderLetter, 
				  @FolderName = @ArbiterName_FolderName, @ParentFolderLetter = @Arbiter_FolderLetter 
					   , @FolderCode = @ArbiterName_FolderCode OUTPUT
			   end
			   	   
		       ELSE IF @SubAgentCode <> -1 --اگر زیرعامل داریم
		        begin
			   	 select @ArbiterName_FolderLetter='FRArSu'+@Arbiter+@SubAgentCode+@FestivalNo
			   	 
	       		 EXEC  [dbo].[SP_GEN_ReturnFolderCode]   @FolderLetter = @ArbiterName_FolderLetter, 
				  @FolderName = @ArbiterName_FolderName, @ParentFolderLetter = @SubAgent_FolderLetter 
					   , @FolderCode = @ArbiterName_FolderCode OUTPUT
				end
			 --*****************اینجا پرمیژن برای مدیر عام و کارشناس عامل همان استان تعریف می کنیم
				   
			 EXEC SP_GEN_AssignFolderPermissions @FolderCode = @Arbiter_FolderCode, @PermissionXML = @PermissionXML	
		  
		  
		  DELETE from @ArbiterTemp where ArbiterUserCode =@Arbiter
		end
		
		
		SET @Comment = N'ثبت اطلاعات طرح کسب و کار آزاد، ' + @FormCompeleteName

		if Not exists (Select * from wfd_FolderContain where FolderCode=@ArbiterName_FolderCode and DTC=@BusinessPlan_DTC and
		               DC=@DocumentCode and Comment=@Comment and IsCompile=1)
			
		EXEC [dbo].[sp_DocsFolderAssign] @ArbiterName_FolderCode, @BusinessPlan_DTC, @DocumentCode , @Comment , 1 , @AssignCode OUTPUT
		
	   END		
		
	  end 
	 end
    END	       
